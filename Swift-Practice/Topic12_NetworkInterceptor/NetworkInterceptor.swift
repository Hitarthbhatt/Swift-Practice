import Foundation

// MARK: - Response & Error

struct NetworkResponse: Sendable {
    let request: URLRequest
    let response: HTTPURLResponse
    let data: Data
}

enum NetworkError: Error, LocalizedError {
    case unacceptableStatusCode(Int)
    case retryLimitExceeded
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .unacceptableStatusCode(let code): return "HTTP \(code)"
        case .retryLimitExceeded:               return "Retry limit exceeded"
        case .unauthorized:                     return "Unauthorized — refresh failed"
        }
    }
}

// MARK: - Adapter (mutate request before send)

protocol RequestAdapter: Sendable {
    func adapt(_ request: URLRequest) async throws -> URLRequest
}

// MARK: - Retrier (decide retry on failure or non-2xx)

enum RetryDecision: Sendable {
    case doNotRetry
    case retry
    case retryAfter(Duration)
    case retryWith(URLRequest)
}

protocol RequestRetrier: Sendable {
    func retry(
        _ request: URLRequest,
        for response: HTTPURLResponse?,
        dueTo error: Error?,
        attempt: Int
    ) async -> RetryDecision
}

// MARK: - Observer (read-only event taps)

protocol NetworkEventObserver: Sendable {
    func willSend(_ request: URLRequest, attempt: Int) async
    func didReceive(_ response: NetworkResponse, attempt: Int) async
    func didFail(_ request: URLRequest, error: Error, attempt: Int) async
}

extension NetworkEventObserver {
    func willSend(_ request: URLRequest, attempt: Int) async {}
    func didReceive(_ response: NetworkResponse, attempt: Int) async {}
    func didFail(_ request: URLRequest, error: Error, attempt: Int) async {}
}
