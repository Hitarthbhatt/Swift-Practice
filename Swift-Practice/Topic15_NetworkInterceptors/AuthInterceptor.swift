import Foundation

// Auth: attach a bearer token before the request continues down the chain.

struct AuthInterceptor: Interceptor {
    let token: String
    let recorder: Recorder

    func intercept(_ request: HTTPRequest, next: Responder) async throws -> HTTPResponse {
        var request = request
        request.headers["Authorization"] = "Bearer \(token)"
        recorder.log("🔑 Auth · added Authorization header")
        return try await next(request)
    }
}
