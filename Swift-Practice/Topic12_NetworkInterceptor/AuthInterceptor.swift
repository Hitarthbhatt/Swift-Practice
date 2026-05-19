import Foundation

// MARK: - Auth Interceptor
//
// Acts as BOTH:
//   - RequestAdapter: injects `Authorization: Bearer <token>`
//   - RequestRetrier: on 401, refreshes once, replays request with new token
//
// Concurrent 401s: actor + in-flight `Task` dedup so only one refresh runs.
// All other callers await that same task. (Topic 8 pattern.)

actor AuthInterceptor {
    private(set) var accessToken: String
    private(set) var refreshCount: Int = 0
    private var refreshTask: Task<String, Error>?
    private let performRefresh: @Sendable () async throws -> String

    init(initialToken: String, refresh: @Sendable @escaping () async throws -> String) {
        self.accessToken = initialToken
        self.performRefresh = refresh
    }

    func expireToken() { accessToken = "EXPIRED" }

    func refreshToken() async throws -> String {
        if let existing = refreshTask {
            return try await existing.value
        }
        let task = Task<String, Error> { [performRefresh] in
            try await performRefresh()
        }
        refreshTask = task
        do {
            let token = try await task.value
            accessToken = token
            refreshCount += 1
            refreshTask = nil
            return token
        } catch {
            refreshTask = nil
            throw error
        }
    }
}

extension AuthInterceptor: RequestAdapter {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return req
    }
}

extension AuthInterceptor: RequestRetrier {
    func retry(
        _ request: URLRequest,
        for response: HTTPURLResponse?,
        dueTo error: Error?,
        attempt: Int
    ) async -> RetryDecision {
        // Only handle 401, and only refresh once per request lifecycle.
        guard response?.statusCode == 401, attempt == 1 else { return .doNotRetry }
        do {
            let newToken = try await refreshToken()
            var newRequest = request
            newRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            return .retryWith(newRequest)
        } catch {
            return .doNotRetry
        }
    }
}
