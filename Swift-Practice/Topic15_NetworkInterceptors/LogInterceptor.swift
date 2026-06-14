import Foundation

// Log: narrate the request going out and the response coming back.

struct LogInterceptor: Interceptor {
    let recorder: Recorder

    func intercept(_ request: HTTPRequest, next: Responder) async throws -> HTTPResponse {
        recorder.log("➡️ \(request.method) \(request.path)")
        do {
            let response = try await next(request)
            recorder.log("⬅️ \(response.status) \(response.body)")
            return response
        } catch {
            recorder.log("⬅️ error: \(error.localizedDescription)")
            throw error
        }
    }
}
