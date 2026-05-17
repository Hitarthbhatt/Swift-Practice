import Foundation
import SwiftData

// MARK: - View Model
//
// Sits between the SwiftUI view and the @MainActor PersistentOperationQueue.
// Owns the queue, drains its event stream into @Observable state that the
// view binds to, and exposes user actions as plain methods.

@Observable
@MainActor
final class QueueingViewModel {
    // MARK: Bound state

    var counts: QueueCounts = QueueCounts()
    var operations: [OperationSummary] = []
    var log: [String] = []
    var isPaused: Bool = false
    var failureRate: Double = 0.35

    // MARK: Dependencies

    let queue: PersistentOperationQueue
    let server: MockSyncServer

    // Used to cycle through a handful of fake entity IDs so per-entity FIFO
    // and cross-entity parallelism are both observable in the demo.
    private let entityIds = ["note-A", "note-B", "note-C", "note-D"]
    private var bindTask: Task<Void, Never>?

    init(context: ModelContext) {
        let server = MockSyncServer(failureRate: 0.35)
        self.server = server
        self.queue = PersistentOperationQueue(context: context, server: server)
    }

    // MARK: - Lifecycle

    // Starts the queue and keeps the view's state in sync with queue events.
    // Called from `.task { await vm.bind() }`, so it's cancelled when the
    // view disappears.
    func bind() async {
        queue.start()
        refresh()

        for await event in queue.events {
            switch event {
            case .log(let line):
                log.insert(line, at: 0)
                if log.count > 200 { log.removeLast(log.count - 200) }
            case .stateChanged:
                refresh()
            }
        }
    }

    private func refresh() {
        counts = queue.counts()
        operations = queue.snapshot()
        isPaused = queue.isPaused
    }

    // MARK: - User actions

    func enqueueRandom() {
        let entity = entityIds.randomElement() ?? "note-A"
        let kind = SyncOperationKind.allCases.randomElement() ?? .update
        let payload = Data("{\"entity\":\"\(entity)\",\"at\":\"\(Date.now.timeIntervalSince1970)\"}".utf8)
        queue.enqueue(entityId: entity, kind: kind, payload: payload)
    }

    // Enqueues a burst of 10 ops. Two of them target the SAME entity back-to-back,
    // which showcases per-entity FIFO: the second one can't start until the first
    // finishes, even while other entities run in parallel.
    func enqueueBurst() {
        // Ten ops: two on note-A back-to-back, the rest spread across B/C/D.
        let plan: [(String, SyncOperationKind)] = [
            ("note-A", .create),
            ("note-A", .update),    // must run strictly after note-A create
            ("note-B", .create),
            ("note-C", .create),
            ("note-D", .create),
            ("note-B", .update),
            ("note-C", .update),
            ("note-D", .delete),
            ("note-B", .delete),
            ("note-A", .delete),    // must run strictly after the two earlier note-A ops
        ]
        for (entity, kind) in plan {
            let payload = Data("{\"entity\":\"\(entity)\",\"k\":\"\(kind.rawValue)\"}".utf8)
            queue.enqueue(entityId: entity, kind: kind, payload: payload)
        }
    }

    func togglePause() {
        queue.setPaused(!queue.isPaused)
    }

    func retryAllFailed() {
        queue.retryAllFailed()
    }

    func clearDead() {
        queue.clearDead()
    }

    func clearAll() {
        queue.clearAll()
        log.removeAll()
    }

    func setFailureRate(_ rate: Double) {
        failureRate = rate
        Task { await server.setFailureRate(rate) }
    }
}
