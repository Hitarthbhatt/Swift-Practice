import Foundation

// Retry: on 5xx or a thrown error, wait exponential backoff + jitter, then retry.

struct RetryInterceptor: Interceptor {
    let maxAttempts: Int
    let baseDelay: Double      // seconds

    let recorder: Recorder

    func intercept(_ request: HTTPRequest, next: Responder) async throws -> HTTPResponse {
        var attempt = 1
        while true {
            do {
                let response = try await next(request)
                if response.status >= 500 && attempt < maxAttempts {
                    try await wait(attempt, reason: "HTTP \(response.status)")
                    attempt += 1
                    continue
                }
                return response
            } catch {
                guard attempt < maxAttempts else { throw error }
                try await wait(attempt, reason: error.localizedDescription)
                attempt += 1
            }
        }
    }

    private func wait(_ attempt: Int, reason: String) async throws {
        let raw = baseDelay * pow(2.0, Double(attempt - 1))
        let delay = min(raw * Double.random(in: 0.8...1.2), 5.0)
        recorder.log("⚠️ \(reason) · retry \(attempt)/\(maxAttempts - 1) in \(Int(delay * 1000))ms")
        try await Task.sleep(for: .seconds(delay))
    }
}
