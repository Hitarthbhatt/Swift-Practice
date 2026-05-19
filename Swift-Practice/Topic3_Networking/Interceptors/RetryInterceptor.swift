import Foundation

// MARK: - Retry Interceptor
//
// Exponential backoff with jitter. Retries on:
//   - Configurable transient status codes (default: 408, 429, 5xx)
//   - Configurable transient `URLError` codes (timeout, no connectivity…)
// Never retries non-idempotent verbs (POST by default) — caller must
// supply an idempotency key and add "POST" to `idempotentMethods` if safe.
//
// Delay = baseDelayMs × 2^(attempt-1) × random(0.8…1.2)

struct RetryInterceptor: RequestRetrier {
    let maxRetries: Int
    let baseDelayMs: Int
    let retryableStatusCodes: Set<Int>
    let idempotentMethods: Set<String>
    let retryableErrors: @Sendable (Error) -> Bool

    init(
        maxRetries: Int = 3,
        baseDelayMs: Int = 300,
        retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504],
        idempotentMethods: Set<String> = ["GET", "PUT", "DELETE", "HEAD", "OPTIONS"],
        retryableErrors: @Sendable @escaping (Error) -> Bool = { RetryInterceptor.isTransientURLError($0) }
    ) {
        self.maxRetries = maxRetries
        self.baseDelayMs = baseDelayMs
        self.retryableStatusCodes = retryableStatusCodes
        self.idempotentMethods = idempotentMethods
        self.retryableErrors = retryableErrors
    }

    func retry(
        _ request: URLRequest,
        for response: HTTPURLResponse?,
        dueTo error: Error?,
        attempt: Int
    ) async -> RetryDecision {
        guard attempt <= maxRetries else { return .doNotRetry }
        guard idempotentMethods.contains(request.httpMethod ?? "GET") else { return .doNotRetry }
        if let response, !retryableStatusCodes.contains(response.statusCode) { return .doNotRetry }
        if let error, !retryableErrors(error) { return .doNotRetry }

        let factor = pow(2.0, Double(attempt - 1)) * Double.random(in: 0.8...1.2)
        let delayMs = Int(Double(baseDelayMs) * factor)
        return .retryAfter(.milliseconds(delayMs))
    }

    static func isTransientURLError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost,
             .notConnectedToInternet, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}
