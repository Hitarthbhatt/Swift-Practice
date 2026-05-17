import Foundation
import SwiftData

// MARK: - Persistent Operation Queue · Models
//
// Interview framing: "How do you build an offline-first sync engine?"
//
// The queue is the backbone. It must:
//   1. Survive app restart      → SwiftData @Model persisted to disk
//   2. Guarantee per-entity FIFO → ops on the same entity apply in order
//   3. Tolerate retries safely  → each op carries an idempotency key (UUID)
//                                 the server dedupes on that key
//   4. Expose a state machine   → pending → inflight → (removed | failed → dead)
//
// Why idempotency keys matter:
//   We retry on failure. Sometimes the server DID receive our request but
//   the response was lost (e.g. TCP reset after the write committed).
//   Without a dedup key, the retry would double-apply the mutation.
//   With a client-generated UUID sent on every attempt, the server can say
//   "I've already applied this key — no-op, return the prior result".

// MARK: - Kind

enum SyncOperationKind: String, Codable, CaseIterable, Sendable {
    case create
    case update
    case delete

    var symbol: String {
        switch self {
        case .create: "➕"
        case .update: "✏️"
        case .delete: "🗑️"
        }
    }
}

// MARK: - State machine

enum SyncOperationState: String, Codable, Sendable {
    case pending   // waiting in queue, eligible to dispatch
    case inflight  // currently being sent to the server
    case failed    // last attempt failed, will be retried after a delay
    case dead      // exceeded maxAttempts, parked — needs manual intervention

    var label: String {
        switch self {
        case .pending:  "Pending"
        case .inflight: "In-flight"
        case .failed:   "Failed"
        case .dead:     "Dead"
        }
    }
}

// MARK: - @Model

// Stored form of an operation. Lives in SwiftData.
// Enum properties are persisted as raw strings so SwiftData predicates can
// query them — `#Predicate` cannot reference computed properties.
@Model
final class SyncOperation {
    // Client-generated idempotency key. Travels with every retry attempt.
    var id: UUID

    // Entity being mutated. The scheduler uses this to enforce per-entity FIFO:
    // two ops on the same entityId never run in parallel.
    var entityId: String

    // Opaque payload (e.g. JSON of the Note the UI mutated). The queue never
    // looks inside — that's the business layer's concern.
    var payload: Data

    // Enqueue time — used as the ordering key when picking the next op.
    var enqueuedAt: Date

    // Raw-storage enum fields. Use `kind` / `state` as the typed API.
    var kindRaw: String
    var stateRaw: String

    // Retry bookkeeping.
    var attempts: Int
    var lastError: String?

    var kind: SyncOperationKind {
        get { SyncOperationKind(rawValue: kindRaw) ?? .update }
        set { kindRaw = newValue.rawValue }
    }

    var state: SyncOperationState {
        get { SyncOperationState(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        entityId: String,
        kind: SyncOperationKind,
        payload: Data,
        enqueuedAt: Date = .now
    ) {
        self.id = id
        self.entityId = entityId
        self.payload = payload
        self.enqueuedAt = enqueuedAt
        self.kindRaw = kind.rawValue
        self.stateRaw = SyncOperationState.pending.rawValue
        self.attempts = 0
        self.lastError = nil
    }
}

// MARK: - Snapshot DTOs
//
// The queue exposes Sendable value types to the UI instead of @Model objects
// directly. This keeps SwiftData's isolation domain from leaking into views
// and makes it trivial to diff / identify rows in SwiftUI.

struct OperationSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let entityId: String
    let kind: SyncOperationKind
    let state: SyncOperationState
    let attempts: Int
    let lastError: String?
}

struct QueueCounts: Sendable, Equatable {
    var pending: Int = 0
    var inflight: Int = 0
    var failed: Int = 0
    var dead: Int = 0

    var total: Int { pending + inflight + failed + dead }
}
