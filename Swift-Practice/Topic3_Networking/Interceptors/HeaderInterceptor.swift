import Foundation

struct HeaderInterceptor: RequestAdapter {
    let headers: [String: String]

    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        // Don't clobber a caller-set value (e.g. per-request Accept).
        for (key, value) in headers where req.value(forHTTPHeaderField: key) == nil {
            req.setValue(value, forHTTPHeaderField: key)
        }
        return req
    }
}
