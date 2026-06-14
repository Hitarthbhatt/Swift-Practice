import Foundation

// MARK: - Retry Policies
//
// Interview: When should you retry?
//   ✅ Transient failures: 429, 503, network timeout, DNS failure
//   ❌ Permanent failures: 400, 401, 403, 404 — retrying wastes resources
//
// Thundering herd problem: if N clients all fail at t=0 and retry at t=1s,
// they all hammer the server at once. Jitter spreads them out randomly.

// MARK: Protocol

protocol RetryPolicy {
    var maxAttempts: Int { get }
    var name: String { get }
    func delay(forAttempt attempt: Int) -> Duration   // attempt is 0-indexed
}

// MARK: Exponential Backoff
// delay = base × 2^attempt  (1s, 2s, 4s, 8s, 16s …)
// Jitter: adds ±30% randomness → prevents thundering herd
// Cap: prevents delays growing unbounded in long retry chains

struct ExponentialBackoff: RetryPolicy {
    var maxAttempts: Int = 5
    var base: Double = 1.0          // seconds
    var cap: Double = 30.0          // max delay in seconds
    var jitter: Bool = true
    var name: String { jitter ? "Exponential + Jitter" : "Exponential" }

    func delay(forAttempt attempt: Int) -> Duration {
        var seconds = base * pow(2.0, Double(attempt))
        if jitter { seconds *= Double.random(in: 0.7...1.3) }
        return .milliseconds(Int(min(seconds, cap) * 1000))
    }
}

// MARK: Linear Backoff
// delay = base × (attempt + 1)  (1s, 2s, 3s, 4s, 5s …)
// Simpler than exponential; grows predictably.
// Use when server recovery time is relatively constant.

struct LinearBackoff: RetryPolicy {
    var maxAttempts: Int = 5
    var base: Double = 1.0
    var name: String { "Linear" }

    func delay(forAttempt attempt: Int) -> Duration {
        .milliseconds(Int(base * Double(attempt + 1) * 1000))
    }
}

// MARK: - Generic Retry Executor

/// Retries `operation` according to `policy`. Logs each event via `onEvent`.
/// Throws the last error if all attempts fail.
/// Propagates CancellationError immediately — never retries a cancelled task.
@discardableResult
func withRetry<T>(
    policy: any RetryPolicy,
    onEvent: @MainActor @escaping (String) -> Void,
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?

    for attempt in 0..<policy.maxAttempts {
        try Task.checkCancellation()
        onEvent("→ Attempt \(attempt + 1)/\(policy.maxAttempts)")

        do {
            let result = try await operation()
            onEvent("✅ Succeeded on attempt \(attempt + 1)")
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            lastError = error
            if attempt < policy.maxAttempts - 1 {
                let d = policy.delay(forAttempt: attempt)
                let secs = String(format: "%.1f", Double(d.components.seconds) + Double(d.components.attoseconds) * 1e-18)
                onEvent("❌ Failed · waiting \(secs)s")
                try await Task.sleep(for: d)
            } else {
                onEvent("❌ All \(policy.maxAttempts) attempts exhausted")
            }
        }
    }
    throw lastError ?? URLError(.unknown)
}
