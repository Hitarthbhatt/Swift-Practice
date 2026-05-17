import Foundation
import SwiftData

// MARK: - Persistent Operation Queue
//
// The core of offline-first sync. Lives on @MainActor because SwiftData's
// ModelContext is bound to a single isolation domain, and the main context
// from a ModelContainer is naturally MainActor-isolated.
//
// That sounds like it would block the UI, but it doesn't:
//   · SwiftData fetches against ~100s of rows are sub-millisecond.
//   · Network I/O is awaited on `MockSyncServer` (a separate actor), and
//     every await suspends MainActor — the UI thread is free to paint
//     and handle taps while the network call is in flight.
//
// ## Scheduling rules
//
// 1. **Per-entity FIFO.** Two ops targeting the same `entityId` never run
//    concurrently. The oldest pending op for that entity must finish before
//    the next one starts. This preserves the user's intended order of edits.
//
// 2. **Cross-entity parallelism.** Up to `maxConcurrency` ops for DIFFERENT
//    entities can run at once. Independent work shouldn't block itself.
//
// 3. **Retry with delay.** A failed op moves to `failed`, waits
//    `baseRetryDelay`, then returns to `pending`. After `maxAttempts` total
//    failures it becomes `dead` — parked until manually retried or cleared.
//    (Production code would plug Topic 8's ExponentialBackoff in here.)
//
// 4. **Crash recovery.** On `start()`, any `inflight` rows left over from a
//    prior process are reset to `pending`. The idempotency key makes this
//    safe — if the server already saw that UUID, it'll dedup the replay.

// Events the queue emits to observers. `.log` pushes human-readable lines
// to the UI console; `.stateChanged` is a ping telling the view to refetch
// its snapshot so rows and counts stay fresh.
enum QueueEvent: Sendable {
    case log(String)
    case stateChanged
}

@MainActor
final class PersistentOperationQueue {
    // MARK: Configuration

    private let context: ModelContext
    private let server: MockSyncServer
    private let maxAttempts: Int
    private let maxConcurrency: Int
    private let baseRetryDelay: Duration

    // MARK: Runtime state

    // Entities currently running a worker. Used to enforce per-entity FIFO:
    // pickNext() skips any pending op whose entityId is in this set.
    private var inflightEntities: Set<String> = []

    // Workers currently running. Held so callers can reason about cleanup;
    // the queue itself doesn't cancel them mid-flight.
    private var workers: [UUID: Task<Void, Never>] = [:]

    // Simulates "airplane mode". While paused, the scheduler refuses to
    // dispatch. Enqueues still persist — they just pile up as pending until
    // resume() is called.
    private(set) var isPaused: Bool = false

    // MARK: Event stream

    private let continuation: AsyncStream<QueueEvent>.Continuation
    let events: AsyncStream<QueueEvent>

    // MARK: Init

    init(
        context: ModelContext,
        server: MockSyncServer,
        maxAttempts: Int = 5,
        maxConcurrency: Int = 3,
        baseRetryDelay: Duration = .milliseconds(1500)
    ) {
        self.context = context
        self.server = server
        self.maxAttempts = maxAttempts
        self.maxConcurrency = maxConcurrency
        self.baseRetryDelay = baseRetryDelay

        var cont: AsyncStream<QueueEvent>.Continuation!
        self.events = AsyncStream<QueueEvent> { cont = $0 }
        self.continuation = cont
    }

    // MARK: - Lifecycle

    /// Recovers any `inflight` ops from a prior process (treat them as pending
    /// — replaying is safe thanks to idempotency keys) and kicks scheduling.
    func start() {
        recoverInflight()
        emit(.log("▶️ Queue started"))
        schedule()
    }

    private func recoverInflight() {
        let inflightRaw = SyncOperationState.inflight.rawValue
        let desc = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.stateRaw == inflightRaw }
        )
        guard let stale = try? context.fetch(desc), !stale.isEmpty else { return }
        for op in stale {
            op.state = .pending
        }
        try? context.save()
        emit(.log("♻️ Recovered \(stale.count) in-flight op(s) from prior session"))
    }

    // MARK: - Public API

    func enqueue(entityId: String, kind: SyncOperationKind, payload: Data) {
        let op = SyncOperation(entityId: entityId, kind: kind, payload: payload)
        context.insert(op)
        try? context.save()
        emit(.log("➕ Enqueued \(kind.rawValue) on \(entityId) [\(short(op.id))]"))
        emit(.stateChanged)
        schedule()
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        emit(.log(paused ? "⏸️ Paused (simulating offline)" : "▶️ Resumed"))
        emit(.stateChanged)
        if !paused { schedule() }
    }

    func retryAllFailed() {
        let failedRaw = SyncOperationState.failed.rawValue
        let desc = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.stateRaw == failedRaw }
        )
        guard let failed = try? context.fetch(desc) else { return }
        for op in failed {
            op.state = .pending
            op.lastError = nil
        }
        try? context.save()
        emit(.log("🔄 Re-pending \(failed.count) failed op(s)"))
        emit(.stateChanged)
        schedule()
    }

    func clearDead() {
        let deadRaw = SyncOperationState.dead.rawValue
        let desc = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.stateRaw == deadRaw }
        )
        guard let deadOps = try? context.fetch(desc) else { return }
        let n = deadOps.count
        for op in deadOps { context.delete(op) }
        try? context.save()
        if n > 0 { emit(.log("🗑️ Cleared \(n) dead op(s)")) }
        emit(.stateChanged)
    }

    func clearAll() {
        guard let all = try? context.fetch(FetchDescriptor<SyncOperation>()) else { return }
        for op in all { context.delete(op) }
        try? context.save()
        emit(.log("💥 Cleared all ops"))
        emit(.stateChanged)
    }

    // MARK: - Snapshots for the UI

    func counts() -> QueueCounts {
        guard let all = try? context.fetch(FetchDescriptor<SyncOperation>()) else {
            return QueueCounts()
        }
        var c = QueueCounts()
        for op in all {
            switch op.state {
            case .pending:  c.pending += 1
            case .inflight: c.inflight += 1
            case .failed:   c.failed += 1
            case .dead:     c.dead += 1
            }
        }
        return c
    }

    func snapshot(limit: Int = 80) -> [OperationSummary] {
        var desc = FetchDescriptor<SyncOperation>(
            sortBy: [SortDescriptor(\.enqueuedAt, order: .forward)]
        )
        desc.fetchLimit = limit
        guard let rows = try? context.fetch(desc) else { return [] }
        return rows.map {
            OperationSummary(
                id: $0.id,
                entityId: $0.entityId,
                kind: $0.kind,
                state: $0.state,
                attempts: $0.attempts,
                lastError: $0.lastError
            )
        }
    }

    // MARK: - Scheduling core

    // Pulls eligible pending ops and launches workers. Idempotent — safe to
    // call whenever state might have changed (enqueue, completion, resume).
    private func schedule() {
        guard !isPaused else { return }

        while inflightEntities.count < maxConcurrency {
            guard let op = pickNext() else { return }

            inflightEntities.insert(op.entityId)
            op.state = .inflight
            try? context.save()
            emit(.stateChanged)

            // Capture value-type fields so the worker task doesn't hold a
            // reference to the @Model instance (which belongs to MainActor
            // and cannot cross isolation boundaries anyway).
            let opId = op.id
            let entityId = op.entityId
            let kind = op.kind
            let payload = op.payload

            workers[opId] = Task { [self] in
                await runWorker(opId: opId, entityId: entityId, kind: kind, payload: payload)
            }
        }
    }

    // Returns the oldest pending op whose entity isn't already in flight.
    private func pickNext() -> SyncOperation? {
        let pendingRaw = SyncOperationState.pending.rawValue
        var desc = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.stateRaw == pendingRaw },
            sortBy: [SortDescriptor(\.enqueuedAt, order: .forward)]
        )
        desc.fetchLimit = 50
        guard let rows = try? context.fetch(desc) else { return nil }
        for candidate in rows where !inflightEntities.contains(candidate.entityId) {
            return candidate
        }
        return nil
    }

    // MARK: - Worker

    private func runWorker(
        opId: UUID,
        entityId: String,
        kind: SyncOperationKind,
        payload: Data
    ) async {
        emit(.log("📤 \(kind.symbol) \(entityId) sending… [\(short(opId))]"))
        do {
            let freshApply = try await server.submit(
                id: opId, kind: kind, entityId: entityId, payload: payload
            )
            finishSuccess(opId: opId, entityId: entityId, freshApply: freshApply)
        } catch {
            finishFailure(opId: opId, entityId: entityId, error: error)
        }
    }

    private func finishSuccess(opId: UUID, entityId: String, freshApply: Bool) {
        if let op = fetch(opId) {
            context.delete(op)
            try? context.save()
        }
        inflightEntities.remove(entityId)
        workers[opId] = nil
        let tag = freshApply ? "" : " (server dedup)"
        emit(.log("✅ \(entityId) [\(short(opId))]\(tag)"))
        emit(.stateChanged)
        schedule()
    }

    private func finishFailure(opId: UUID, entityId: String, error: Error) {
        var shouldScheduleRetry = false

        if let op = fetch(opId) {
            op.attempts += 1
            op.lastError = error.localizedDescription
            if op.attempts >= maxAttempts {
                op.state = .dead
                emit(.log("💀 \(entityId) DEAD after \(op.attempts) attempts"))
            } else {
                op.state = .failed
                emit(.log("❌ \(entityId) failed (\(op.attempts)/\(maxAttempts))"))
                shouldScheduleRetry = true
            }
            try? context.save()
        }

        inflightEntities.remove(entityId)
        workers[opId] = nil
        emit(.stateChanged)

        if shouldScheduleRetry {
            Task { [self, baseRetryDelay] in
                try? await Task.sleep(for: baseRetryDelay)
                requeueIfStillFailed(opId: opId)
            }
        }

        // Free slot — try to dispatch another op from a different entity now.
        schedule()
    }

    private func requeueIfStillFailed(opId: UUID) {
        guard let op = fetch(opId), op.state == .failed else { return }
        op.state = .pending
        try? context.save()
        emit(.log("🔄 Retrying \(op.entityId) [\(short(opId))]"))
        emit(.stateChanged)
        schedule()
    }

    // MARK: - Helpers

    private func fetch(_ id: UUID) -> SyncOperation? {
        var desc = FetchDescriptor<SyncOperation>(
            predicate: #Predicate { $0.id == id }
        )
        desc.fetchLimit = 1
        return try? context.fetch(desc).first
    }

    private func emit(_ event: QueueEvent) {
        continuation.yield(event)
    }

    private func short(_ id: UUID) -> String {
        String(id.uuidString.prefix(8))
    }
}
