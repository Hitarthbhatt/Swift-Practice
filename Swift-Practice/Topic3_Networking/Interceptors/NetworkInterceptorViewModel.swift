import Foundation

@Observable @MainActor
final class NetworkInterceptorViewModel {
    enum Scenario: String, CaseIterable, Identifiable {
        case happyPath        = "Happy path (200)"
        case authExpired      = "Token expired (401 → refresh → 200)"
        case transientFailure = "Transient failure (timeout × 2 → 200)"
        case permanentFailure = "Server error (500 × 4)"

        var id: String { rawValue }
    }

    var log: [String] = []
    var resultBody: String = ""
    var scenario: Scenario = .happyPath
    var isRunning = false
    var tokenLabel: String = "tok_initial"
    var refreshCount: Int = 0

    private let transport: MockTransport
    private let auth: AuthInterceptor
    private let client: APIClient
    private let logContinuation: AsyncStream<String>.Continuation
    private var logPump: Task<Void, Never>?

    init() {
        let body = Data(#"{"data":"hello","items":42}"#.utf8)
        let transport = MockTransport(behavior: .success(statusCode: 200, body: body))
        let auth = AuthInterceptor(initialToken: "tok_initial") {
            try await Task.sleep(for: .milliseconds(500))
            return "tok_\(Int.random(in: 10_000...99_999))"
        }

        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        let logger = LoggingInterceptor { line in continuation.yield(line) }

        let config = APIClient.Configuration(
            adapters: [
                HeaderInterceptor(headers: [
                    "Accept":   "application/json",
                    "X-Client": "ios-system-design-prep"
                ]),
                auth
            ],
            retriers: [auth, RetryInterceptor(maxRetries: 2, baseDelayMs: 250)],
            observers: [logger],
            maxRetries: 4
        )

        self.transport       = transport
        self.auth            = auth
        self.client          = APIClient(transport: transport, configuration: config)
        self.logContinuation = continuation

        logPump = Task { [weak self] in
            for await line in stream {
                self?.log.insert(line, at: 0)
            }
        }
    }

    deinit {
        logContinuation.finish()
    }

    func sendRequest() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        await transport.setBehavior(makeBehavior())

        var request = URLRequest(url: URL(string: "https://api.example.com/v1/items")!)
        request.httpMethod = "GET"

        do {
            let response = try await client.send(request)
            resultBody = String(data: response.data, encoding: .utf8) ?? "<binary>"
        } catch {
            resultBody = "Failed: \(error.localizedDescription)"
        }

        tokenLabel    = await auth.accessToken
        refreshCount  = await auth.refreshCount
    }

    func expireToken() async {
        await auth.expireToken()
        tokenLabel = await auth.accessToken
        log.insert("⚠️ Token forced to EXPIRED — switch scenario to 401 to see refresh", at: 0)
    }

    func clearLog() {
        log = []
        resultBody = ""
    }

    private func makeBehavior() -> MockTransport.Behavior {
        let okBody = Data(#"{"data":"hello","items":42}"#.utf8)
        switch scenario {
        case .happyPath:
            return .success(statusCode: 200, body: okBody)
        case .authExpired:
            return .sequence([
                .success(statusCode: 401, body: Data()),
                .success(statusCode: 200, body: okBody)
            ])
        case .transientFailure:
            return .sequence([
                .fail(.timedOut),
                .fail(.timedOut),
                .success(statusCode: 200, body: okBody)
            ])
        case .permanentFailure:
            return .sequence([
                .success(statusCode: 500, body: Data()),
                .success(statusCode: 500, body: Data()),
                .success(statusCode: 500, body: Data()),
                .success(statusCode: 500, body: Data())
            ])
        }
    }
}
