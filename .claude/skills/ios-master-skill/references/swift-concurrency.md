# Swift Concurrency

## Project Settings (Check First)

| Setting | SwiftPM | Xcode |
|---------|---------|-------|
| Language mode | `swiftLanguageVersions` / `-swift-version` | Swift Language Version |
| Strict concurrency | `.enableExperimentalFeature("StrictConcurrency=targeted")` | `SWIFT_STRICT_CONCURRENCY` |
| Default isolation | `.defaultIsolation(MainActor.self)` | `SWIFT_DEFAULT_ACTOR_ISOLATION` |
| Upcoming features | `.enableUpcomingFeature(...)` | `SWIFT_UPCOMING_FEATURE_*` |

**If unknown, confirm before giving migration-sensitive guidance.**

## Core Rules

- Prefer **Swift Concurrency** over GCD for new code.
- Prefer **structured concurrency** (task groups) over unstructured (`Task {}`).
- Prefer `async`/`await` over closure-based variants.
- Never use `Task.sleep(nanoseconds:)` — use `Task.sleep(for:)`.
- Never use `@unchecked Sendable` to fix compiler errors. Prefer actors, value types, or `sending` parameters.
- `Task.detached` is rarely correct. Check intent carefully.

## Actors

### Reentrancy (Most Common Bug)

After every `await` inside an actor, all assumptions about state are invalidated:

```swift
// BUG — state may change across await, force unwrap can crash
actor Cache {
    var items: [String: Data] = [:]
    func fetch(_ key: String) async throws -> Data {
        if items[key] == nil {
            items[key] = try await download(key)
        }
        return items[key]!
    }
}

// FIX — capture result in local
actor Cache {
    var items: [String: Data] = [:]
    func fetch(_ key: String) async throws -> Data {
        if let existing = items[key] { return existing }
        let data = try await download(key)
        items[key] = data
        return data
    }
}
```

For deduplication, store in-flight `Task` handles:

```swift
actor Cache {
    var items: [String: Data] = [:]
    var inFlight: [String: Task<Data, Error>] = [:]

    func fetch(_ key: String) async throws -> Data {
        if let cached = items[key] { return cached }
        if let task = inFlight[key] { return try await task.value }

        let task = Task { try await download(key) }
        inFlight[key] = task
        do {
            let data = try await task.value
            items[key] = data
            inFlight[key] = nil
            return data
        } catch {
            inFlight[key] = nil
            throw error
        }
    }
}
```

### Global Actor Inference

`@MainActor` propagates to:
- Subclasses of `@MainActor` classes
- Conformances to `@MainActor` protocols (including SwiftUI `View`)
- Extensions of `@MainActor` types
- Values stored through actor-isolated property wrapper storage

Does NOT propagate to:
- Closures passed to non-isolated functions

### isolated Parameters

```swift
func updateUI(on actor: isolated MainActor) {
    // Runs on the main actor
}
```

### assertIsolated (Debug)

```swift
MainActor.assertIsolated()  // Traps in debug if not on main actor
```

## Structured Concurrency

### async let vs Task Groups

- `async let`: fixed number of operations, different return types
- Task group: dynamic number of operations, same type

### Task Groups Over Loops

```swift
// WRONG — no cancellation, leaked tasks
for url in urls { Task { try await fetch(url) } }

// RIGHT — structured, cancellable
let results = try await withThrowingTaskGroup { group in
    for url in urls { group.addTask { try await fetch(url) } }
    var collected = [Data]()
    for try await result in group { collected.append(result) }
    return collected
}
```

### Discarding Task Groups (Swift 5.9+)

For fire-and-forget child tasks:

```swift
await withDiscardingTaskGroup { group in
    for conn in connections { group.addTask { await conn.sendHeartbeat() } }
}
```

### Limiting Concurrency

```swift
try await withThrowingTaskGroup { group in
    let maxConcurrent = 4
    var iterator = urls.makeIterator()
    for _ in 0..<maxConcurrent {
        guard let url = iterator.next() else { break }
        group.addTask { try await fetch(url) }
    }
    for try await result in group {
        process(result)
        if let url = iterator.next() { group.addTask { try await fetch(url) } }
    }
}
```

### Error Handling with Partial Results

Catch errors inside each child task to prevent group cancellation:

```swift
await withTaskGroup(of: (URL, Result<Data, Error>).self) { group in
    for url in urls {
        group.addTask {
            do { return (url, .success(try await fetch(url))) }
            catch { return (url, .failure(error)) }
        }
    }
    for await (url, result) in group { ... }
}
```

## Unstructured Tasks

### Task vs Task.detached

- `Task {}` — inherits caller's actor isolation
- `Task.detached {}` — sheds isolation and priority. Rarely correct.

### When Task {} Is a Code Smell

- **Task inside `onAppear()`**: Use `.task()` modifier instead.
- **Task to bridge sync→async when caller could be async**: Make caller async.
- **Ignoring throwing task errors**: Handle errors inside the closure.

## Cancellation

Cancellation is **cooperative** — setting the flag doesn't stop execution.

- `try Task.checkCancellation()` — throws if cancelled
- `Task.isCancelled` — Bool for non-throwing contexts
- `.task()` modifier cancels automatically on disappear

```swift
func processAll(_ items: [Item]) async throws {
    for item in items {
        try Task.checkCancellation()
        try await process(item)
    }
}
```

### withTaskCancellationHandler

Bridges Swift cancellation to legacy APIs:

```swift
func observe() async throws -> [Change] {
    let operation = CKQueryOperation(query: query)
    return try await withTaskCancellationHandler {
        try await performOperation(operation)
    } onCancel: {
        operation.cancel()
    }
}
```

### Broken Patterns

- **Catching and ignoring `CancellationError`**: Always filter it out before error handling.
- **Forgetting to cancel stored tasks**: Cancel previous task before starting new one, and in deinit.
- **No cancellation checks in CPU-bound loops**: Insert `try Task.checkCancellation()`.

## Async Streams

### Prefer makeStream(of:) Factory

```swift
let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
```

### Continuation Lifecycle

Must be finished exactly once. Always finish in cleanup paths. Use `onTermination` for cleanup.

### Buffering

Default is `.unbounded`. For high-throughput producers, specify policy:

```swift
let (stream, continuation) = AsyncStream.makeStream(
    of: SensorReading.self,
    bufferingPolicy: .bufferingNewest(100)
)
```

## Bridging Sync/Async

### Checked Continuations

**The continuation must be resumed exactly once on every code path.**

- Zero resumes: caller hangs forever
- Two resumes: runtime crash

Default to `withCheckedContinuation`/`withCheckedThrowingContinuation` everywhere. Only use `unsafe` variants after profiling proves necessity.

### Wrapping Delegates

Single-shot: `withCheckedContinuation`. Multi-value: `AsyncStream` with `makeStream(of:)`.

### @unchecked Sendable

Legitimate uses: types with internal locking that are provably thread-safe.
Red flags: applied to silence compiler errors without understanding the race.

## Swift 6.2 Features

### Default Actor Isolation

Module opt-in to MainActor by default. Most declarations behave as `@MainActor`. Per-module setting. Suspending I/O does NOT block main actor.

### Isolated Conformances

```swift
@MainActor
class User: @MainActor Equatable { ... }
```

### nonisolated Async Stays on Caller's Actor

In Swift 6.2, `nonisolated async` functions stay on caller's actor by default (no automatic hop).

### @concurrent

Explicit opt-in for background execution:

```swift
@concurrent
func analyzeReadings(_ readings: [Double]) async -> AnalysisResult { ... }
```

Use for CPU-heavy work (parsing, image processing). Not needed for async I/O.

### Task.immediate

Starts running synchronously before caller continues:

```swift
Task.immediate { print("Runs now") }
```

### isolated deinit

```swift
@MainActor
class Session {
    isolated deinit { user.isLoggedIn = false }
}
```

### Task Naming

```swift
let task = Task(name: "MyTask") { ... }
group.addTask(name: "Stories \(i)") { ... }
```

### Priority Escalation

```swift
try await withTaskPriorityEscalationHandler {
    ...
} onPriorityEscalated: { old, new in ... }
```

## Concurrency Tool Selection

| Need | Tool |
|------|------|
| Single async operation | `async/await` |
| Fixed parallel operations | `async let` |
| Dynamic parallel operations | `withTaskGroup` |
| Sync→async bridge | `Task {}` |
| Shared mutable state | `actor` |
| UI-bound state | `@MainActor` |
| CPU-heavy background work | `@concurrent` |
| Synchronous mutual exclusion | `Mutex` |
