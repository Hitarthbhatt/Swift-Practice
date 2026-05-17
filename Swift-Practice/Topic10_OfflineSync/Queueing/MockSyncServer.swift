import Foundation

// MARK: - Mock Sync Server
//
// Stand-in for a real REST endpoint. The queue calls `submit(...)` and the
// server responds after a tunable latency, failing a tunable fraction of
// requests to exercise the retry path.
//
// The critical behavior for this demo is **idempotency**: the server tracks
// every UUID it has successfully applied. If the same UUID arrives twice,
// the second call returns success without re-applying anything. That's what
// makes client-side retries safe.

actor MockSyncServer {
    // The set of idempotency keys the server has already applied.
    // In a real backend this lives in a database with a unique index on
    // the idempotency key column — here, a Set is enough to prove the point.
    private var applied: Set<UUID> = []

    // Tunable so the UI slider can exercise the retry path.
    private(set) var failureRate: Double
    private(set) var latency: Duration

    init(failureRate: Double = 0.35, latency: Duration = .milliseconds(450)) {
        self.failureRate = failureRate
        self.latency = latency
    }

    // Returns `true` if this submission was newly applied, `false` if it was
    // a dedup replay of an already-applied idempotency key. Both are success
    // from the client's perspective — the queue can delete the op either way.
    func submit(
        id: UUID,
        kind: SyncOperationKind,
        entityId: String,
        payload: Data
    ) async throws -> Bool {
        try await Task.sleep(for: latency)

        if applied.contains(id) {
            return false  // idempotent replay → no side effect
        }

        if Double.random(in: 0...1) < failureRate {
            throw URLError(.timedOut)
        }

        applied.insert(id)
        return true
    }

    func setFailureRate(_ rate: Double) {
        failureRate = max(0, min(1, rate))
    }

    var appliedCount: Int { applied.count }

    func reset() {
        applied.removeAll()
    }
}
