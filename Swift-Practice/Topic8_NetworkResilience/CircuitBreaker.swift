import Foundation

// MARK: - Circuit Breaker
//
// Prevents cascading failures: if a service is down, stop sending it requests.
// Named after the electrical circuit breaker that cuts power on overload.
//
// Three states:
//   Closed   — normal. Failures increment counter. At threshold → Open.
//   Open     — all requests REJECTED immediately (no network call). After timeout → Half-Open.
//   Half-Open — one probe request allowed. Success → Closed. Failure → Open (resets timer).
//
// Interview: difference from retry?
//   Retry = keep trying the same service.
//   Circuit breaker = stop trying until it likely recovers. Fail fast to protect caller + server.
//
// Use in service mesh / API gateway layers; also valid on mobile for repeated background sync.

enum CircuitBreakerError: LocalizedError {
    case open
    var errorDescription: String? {
        "Circuit OPEN — request rejected without a network call (fail-fast)"
    }
}

actor CircuitBreaker {
    enum State {
        case closed
        case open(until: Date)
        case halfOpen

        var label: String {
            switch self {
            case .closed:   return "Closed"
            case .open:     return "Open"
            case .halfOpen: return "Half-Open"
            }
        }
        var color: String {   // returned as string; view maps to Color
            switch self {
            case .closed:   return "green"
            case .open:     return "red"
            case .halfOpen: return "orange"
            }
        }
    }

    private(set) var state: State = .closed
    private var failureCount = 0

    let failureThreshold: Int    // failures before opening
    let recoveryTimeout: TimeInterval   // seconds before half-open probe

    init(failureThreshold: Int = 3, recoveryTimeout: TimeInterval = 8) {
        self.failureThreshold = failureThreshold
        self.recoveryTimeout = recoveryTimeout
    }

    // MARK: - Call

    func call<T>(_ operation: () async throws -> T) async throws -> T {
        switch effectiveState() {
        case .open:
            throw CircuitBreakerError.open

        case .closed, .halfOpen:
            do {
                let result = try await operation()
                recordSuccess()
                return result
            } catch is CircuitBreakerError {
                throw CircuitBreakerError.open
            } catch {
                recordFailure()
                throw error
            }
        }
    }

    func reset() { state = .closed; failureCount = 0 }

    var stateLabel: String { effectiveState().label }
    var stateColor: String { effectiveState().color }
    var failures: Int { failureCount }

    // MARK: - Private

    /// Transitions Open → Half-Open when timer expires.
    private func effectiveState() -> State {
        if case .open(let until) = state, Date() >= until {
            state = .halfOpen
        }
        return state
    }

    private func recordSuccess() {
        failureCount = 0
        state = .closed
    }

    private func recordFailure() {
        switch state {
        case .halfOpen:
            // Probe failed → re-open with fresh timer
            trip()
        case .closed:
            failureCount += 1
            if failureCount >= failureThreshold { trip() }
        case .open:
            break
        }
    }

    private func trip() {
        state = .open(until: Date().addingTimeInterval(recoveryTimeout))
        failureCount = 0
    }
}
