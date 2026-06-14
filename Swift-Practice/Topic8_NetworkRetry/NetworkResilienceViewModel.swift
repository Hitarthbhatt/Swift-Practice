import Foundation

@Observable @MainActor
final class NetworkResilienceViewModel {
    // MARK: Shared
    var isRunning = false
    var failureRate: Double = 0.75    // used by all mock operations

    // MARK: Exponential Backoff
    var expLog: [String] = []
    var expJitter = true

    // MARK: Linear Backoff
    var linLog: [String] = []
    var linBase: Double = 1.0

    // MARK: Circuit Breaker
    var cbLog: [String] = []
    var cbStateLabel: String = "Closed"
    var cbStateColor: String = "green"
    var cbFailures: Int = 0
    private let breaker = CircuitBreaker(failureThreshold: 3, recoveryTimeout: 8)

    // MARK: OAuth
    var oauthLog: [String] = []
    var oauthToken: String = "access_tok_abc123"
    var oauthRefreshCount: Int = 0
    var oauthSimulateExpired = false
    private let tokenManager = TokenManager()

    // MARK: - Mock Operation
    // Simulates a flaky network call using `failureRate`.
    private func mockRequest() async throws -> String {
        try await Task.sleep(for: .milliseconds(300))
        if Double.random(in: 0...1) < failureRate {
            throw URLError(.notConnectedToInternet)
        }
        return "HTTP 200 OK"
    }

    // MARK: - Exponential Backoff

    func runExponential() async {
        guard !isRunning else { return }
        isRunning = true; expLog = []
        let policy = ExponentialBackoff(maxAttempts: 5, jitter: expJitter)
        do {
            try await withRetry(policy: policy, onEvent: { [weak self] msg in
                self?.expLog.insert(msg, at: 0)
            }) { [weak self] in
                guard let self else { throw URLError(.cancelled) }
                return try await mockRequest()
            }
        } catch { }
        isRunning = false
    }

    // MARK: - Linear Backoff

    func runLinear() async {
        guard !isRunning else { return }
        isRunning = true; linLog = []
        let policy = LinearBackoff(maxAttempts: 5, base: linBase)
        do {
            try await withRetry(policy: policy, onEvent: { [weak self] msg in
                self?.linLog.insert(msg, at: 0)
            }) { [weak self] in
                guard let self else { throw URLError(.cancelled) }
                return try await mockRequest()
            }
        } catch { }
        isRunning = false
    }

    // MARK: - Circuit Breaker
    // Fires 10 requests with pauses to demonstrate state transitions.

    func runCircuitBreaker() async {
        guard !isRunning else { return }
        isRunning = true; cbLog = []

        for i in 1...10 {
            do {
                let result = try await breaker.call { [weak self] in
                    guard let self else { throw URLError(.cancelled) }
                    return try await mockRequest()
                }
                cbLog.insert("Req \(i): ✅ \(result)", at: 0)
            } catch CircuitBreakerError.open {
                cbLog.insert("Req \(i): 🚫 REJECTED — circuit open (fail-fast)", at: 0)
            } catch {
                cbLog.insert("Req \(i): ❌ \(error.localizedDescription)", at: 0)
            }
            await syncBreakerState()
            try? await Task.sleep(for: .milliseconds(400))
        }
        isRunning = false
    }

    func resetBreaker() {
        Task {
            await breaker.reset()
            await syncBreakerState()
            cbLog.insert("🔄 Circuit breaker reset → Closed", at: 0)
        }
    }

    private func syncBreakerState() async {
        cbStateLabel = await breaker.stateLabel
        cbStateColor  = await breaker.stateColor
        cbFailures    = await breaker.failures
    }

    // MARK: - OAuth Token Refresh

    func runOAuthRequest() async {
        guard !isRunning else { return }
        isRunning = true; oauthLog = []
        do {
            let response = try await authenticatedRequest(
                tokenManager: tokenManager,
                simulateExpired: oauthSimulateExpired,
                onEvent: { [weak self] msg in self?.oauthLog.insert(msg, at: 0) }
            )
            oauthLog.insert("📦 \(response)", at: 0)
        } catch {
            oauthLog.insert("❌ \(error.localizedDescription)", at: 0)
        }
        oauthToken = await tokenManager.accessToken
        oauthRefreshCount = await tokenManager.refreshCount
        isRunning = false
    }

    func expireOAuthToken() {
        oauthSimulateExpired = true
        Task {
            await tokenManager.expireToken()
            oauthToken = await tokenManager.accessToken
        }
        oauthLog.insert("⚠️ Token expired — next request will get 401", at: 0)
    }
}
