import Foundation

struct LoggingInterceptor: NetworkEventObserver {
    let sink: @Sendable (String) -> Void

    func willSend(_ request: URLRequest, attempt: Int) async {
        let method = request.httpMethod ?? "GET"
        let url    = request.url?.absoluteString ?? "<no url>"
        let auth   = request.value(forHTTPHeaderField: "Authorization")
            .map { " auth=\($0.prefix(24))…" } ?? ""
        sink("→ [\(attempt)] \(method) \(url)\(auth)")
    }

    func didReceive(_ response: NetworkResponse, attempt: Int) async {
        sink("← [\(attempt)] HTTP \(response.response.statusCode) (\(response.data.count)B)")
    }

    func didFail(_ request: URLRequest, error: Error, attempt: Int) async {
        sink("✗ [\(attempt)] \(error.localizedDescription)")
    }
}
