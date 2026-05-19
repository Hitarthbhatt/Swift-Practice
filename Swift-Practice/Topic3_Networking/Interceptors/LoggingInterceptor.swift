import Foundation

struct LoggingInterceptor: NetworkEventObserver {
    let sink: (@Sendable (String) -> Void)?

    init(sink: (@Sendable (String) -> Void)? = nil) {
        self.sink = sink
    }

    private func emit(_ line: String) {
        if let sink { sink(line) } else { print(line) }
    }

    func willSend(_ request: URLRequest, attempt: Int) async {
        let method = request.httpMethod ?? "GET"
        let url    = request.url?.absoluteString ?? "<no url>"
        let auth   = request.value(forHTTPHeaderField: "Authorization")
            .map { " auth=\($0.prefix(24))…" } ?? ""
        emit("→ [\(attempt)] \(method) \(url)\(auth)")
    }

    func didReceive(_ response: NetworkResponse, attempt: Int) async {
        emit("← [\(attempt)] HTTP \(response.response.statusCode) (\(response.data.count)B)")
    }

    func didFail(_ request: URLRequest, error: Error, attempt: Int) async {
        emit("✗ [\(attempt)] \(error.localizedDescription)")
    }
}
