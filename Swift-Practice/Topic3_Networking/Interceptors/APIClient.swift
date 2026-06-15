import Foundation

// Builds the chain: folds interceptors right-to-left around the transport.

struct APIClient {
    let interceptors: [Interceptor]
    let transport: Responder

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var responder = transport
        for interceptor in interceptors.reversed() {
            let next = responder              // capture this value, not the loop variable
            responder = { try await interceptor.intercept($0, next: next) }
        }
        return try await responder(request)
    }
}
