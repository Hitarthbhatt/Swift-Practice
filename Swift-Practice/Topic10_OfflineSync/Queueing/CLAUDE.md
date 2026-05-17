# Topic 10 — Queueing

Persistent op queue surviving app kill. SwiftData-backed, per-entity FIFO, idempotency keys, dead-letter.

## Files
- `OperationQueueModels.swift` — `@Model` op entity + status enum + payload codable.
- `PersistentOperationQueue.swift` — actor. Enqueue, dequeue, retry, dead-letter, crash recovery on launch.
- `MockSyncServer.swift` — fake server: configurable failures, idempotency-key dedup.
- `QueueingViewModel.swift` — `@Observable` UI state.
- `QueueingDemoView.swift` — controls to enqueue ops + visualize queue.

## Invariants
- Per-entity ordering preserved (FIFO by `entityId`).
- Idempotency key on each op → server-side dedup safe.
- Crash-recovery: in-flight ops re-queued on launch.
- Max retries → dead-letter; not retried.
