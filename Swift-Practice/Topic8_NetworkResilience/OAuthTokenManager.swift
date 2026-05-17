import Foundation

// MARK: - OAuth Token Refresh + Retry
//
// Flow:
//   1. Send request with current access token
//   2. Server returns 401 Unauthorized (token expired or revoked)
//   3. Use refresh token to get a new access token from auth server
//   4. Retry the original request with the new access token
//   5. If refresh also fails → force logout
//
// Interview: what if two requests get 401 simultaneously?
//   Naive: both trigger refresh → race condition → double refresh
//   Fix: gate refresh behind a Task or lock so only one refresh runs;
//        others await the same refresh task. (token refresh dedup)
//
// In production: Alamofire RequestInterceptor or URLSession delegate intercepts 401.
// On mobile: store refresh token in Keychain (Topic 9: Security).

// MARK: - Token Manager (Actor — prevents concurrent refresh races)

actor TokenManager {
    private(set) var accessToken: String = "access_tok_abc123"
    private(set) var refreshCount: Int = 0
    var isExpired: Bool = false

    // Dedup: if a refresh is already in-flight, return that same task
    private var refreshTask: Task<String, Error>?

    func expireToken() {
        isExpired = true
        accessToken = "EXPIRED"
    }

    /// Thread-safe refresh: concurrent callers all await the same underlying refresh.
    func refresh() async throws -> String {
        if let existing = refreshTask {
            return try await existing.value
        }
        let task = Task<String, Error> {
            try await Task.sleep(for: .milliseconds(900))   // simulate auth server RTT
            let newToken = "access_tok_\(Int.random(in: 10000...99999))"
            return newToken
        }
        refreshTask = task
        do {
            let token = try await task.value
            accessToken = token
            refreshCount += 1
            isExpired = false
            refreshTask = nil
            return token
        } catch {
            refreshTask = nil
            throw error
        }
    }
}

// MARK: - Authenticated Request

/// Sends a request, handles 401 by refreshing the token once, then retries.
func authenticatedRequest(
    tokenManager: TokenManager,
    simulateExpired: Bool,
    onEvent: @MainActor @escaping (String) -> Void
) async throws -> String {
    var token = await tokenManager.accessToken
    await onEvent("→ Sending request")
    await onEvent("  Token: \(token)")

    // First attempt
    let statusCode = simulateExpired ? 401 : 200
    await onEvent("← Server responded: HTTP \(statusCode)")

    if statusCode == 401 {
        await onEvent("⚠️ 401 Unauthorized — access token expired")
        await onEvent("🔄 Refreshing token via refresh_token…")

        token = try await tokenManager.refresh()
        await onEvent("✅ New token: \(token)")
        await onEvent("→ Retrying original request with new token")

        // Retry (always succeeds in mock after refresh)
        try await Task.sleep(for: .milliseconds(400))
        await onEvent("← Server responded: HTTP 200")
    }

    return "{ \"data\": \"success\", \"token_refreshes\": \(await tokenManager.refreshCount) }"
}
