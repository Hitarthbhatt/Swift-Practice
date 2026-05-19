import Foundation

// MARK: - Shared Network Types

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case noData
    case cancelled
    case unknown(Error)
    case unacceptableStatusCode(Int)
    case retryLimitExceeded
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .invalidResponse: "Invalid response"
        case .httpError(let code, _): "HTTP error \(code)"
        case .decodingError(let error): "Decoding failed: \(error.localizedDescription)"
        case .noData: "No data"
        case .cancelled: "Request cancelled"
        case .unknown(let error): error.localizedDescription
        case .unacceptableStatusCode(let code): "HTTP \(code)"
        case .retryLimitExceeded: "Retry limit exceeded"
        case .unauthorized: "Unauthorized — refresh failed"
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct EmptyBody: Encodable {}

// MARK: - Request building protocol
protocol APIRequest {
    associatedtype Response: Decodable

    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var queryItems: [URLQueryItem]? { get }
    var body: (any Encodable)? { get }
}

extension APIRequest {
    var method: HTTPMethod { .get }
    var headers: [String: String]? { nil }
    var queryItems: [URLQueryItem]? { nil }
    var body: (any Encodable)? { nil }
}
