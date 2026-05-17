# Topic 2 — Concurrency & Data Binding

Demos covering concurrency primitives + Observation framework.

## Files
- `ObservableDemo.swift` — `@Observable` macro (replaces `ObservableObject`).
- `AsyncAwaitDemo.swift` — `async/await`, `Task`, `TaskGroup`, cancellation.
- `ActorsDemo.swift` — `actor`, `@MainActor`, `Sendable`, isolation.
- `GCDDemo.swift` — DispatchQueue (legacy reference, prefer async/await).
- `OperationQueueDemo.swift` — Operation/OperationQueue (legacy reference).
- `CombineDemo.swift` — Combine pipelines, publishers, operators.

## Rule
New code = `@Observable` + Swift Concurrency. GCD/Operation/Combine = comparison only.
