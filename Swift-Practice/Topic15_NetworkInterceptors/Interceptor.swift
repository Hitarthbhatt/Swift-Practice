import Foundation

// One protocol for the whole chain: each interceptor wraps `next`.

struct HTTPRequest {
    var method = "GET"
    var path: String
    var headers: [String: String] = [:]
}

struct HTTPResponse {
    let status: Int
    let body: String
}

typealias Responder = (HTTPRequest) async throws -> HTTPResponse

protocol Interceptor {
    func intercept(_ request: HTTPRequest, next: Responder) async throws -> HTTPResponse
}

final class Recorder {
    private(set) var lines: [String] = []
    func log(_ line: String) { lines.append(line) }
}
