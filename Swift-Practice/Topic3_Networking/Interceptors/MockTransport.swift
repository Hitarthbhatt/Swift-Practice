import Foundation

actor MockTransport: NetworkTransport {
    enum Behavior: Sendable {
        case success(statusCode: Int, body: Data)
        case fail(URLError.Code)
        case sequence([Behavior])
    }

    private var behavior: Behavior
    private var sequenceIndex: Int = 0
    var latency: Duration = .milliseconds(200)

    init(behavior: Behavior) { self.behavior = behavior }

    func setBehavior(_ behavior: Behavior) {
        self.behavior = behavior
        sequenceIndex = 0
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await Task.sleep(for: latency)
        let step = nextStep()
        switch step {
        case .success(let code, let body):
            let resp = HTTPURLResponse(
                url: request.url!,
                statusCode: code,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (body, resp)
        case .fail(let code):
            throw URLError(code)
        case .sequence:
            fatalError("nested sequence unsupported")
        }
    }

    private func nextStep() -> Behavior {
        if case .sequence(let items) = behavior {
            let step = items[min(sequenceIndex, items.count - 1)]
            sequenceIndex += 1
            return step
        }
        return behavior
    }
}
