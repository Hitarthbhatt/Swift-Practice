import Foundation

// Mock transport: fail the first N calls with 503, then return finalStatus.

final class MockServer {
    private var calls = 0
    let failFirst: Int
    let finalStatus: Int
    let alwaysStatus: Int?

    init(failFirst: Int = 0, finalStatus: Int = 200, alwaysStatus: Int? = nil) {
        self.failFirst = failFirst
        self.finalStatus = finalStatus
        self.alwaysStatus = alwaysStatus
    }

    func respond(_ request: HTTPRequest) async -> HTTPResponse {
        calls += 1
        if let alwaysStatus { return HTTPResponse(status: alwaysStatus, body: body(for: alwaysStatus)) }
        if calls <= failFirst { return HTTPResponse(status: 503, body: body(for: 503)) }
        return HTTPResponse(status: finalStatus, body: body(for: finalStatus))
    }

    private func body(for status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 401: return "Unauthorized"
        case 503: return "Service Unavailable"
        default: return "Status \(status)"
        }
    }
}
