# Swift Concurrency: Patterns, Bugs & Migration

## Hotspots — Search Targets for Review

| Pattern | Risk | Action |
|---------|------|--------|
| `DispatchQueue` | GCD in app code | Check if Swift concurrency equivalent exists |
| `Task.detached` | Rarely correct | Check if `@concurrent` or task group fits |
| `Task {}` in loop | Leaked tasks | Should be task group |
| `withCheckedContinuation` | Hang/crash | Audit every path resumes exactly once |
| `AsyncStream` (closure form) | Leak | Use `makeStream(of:)` factory |
| `@unchecked Sendable` | Hidden race | Verify internal locking or restructure |
| `MainActor.run {}` | Often unnecessary | Check if already on MainActor |
| Actors with `await` | Reentrancy | Check state assumptions after suspension |
| `!` after `await` in actor | Crash | State may have changed during suspension |

## Common Bug Patterns

### 1. Actor Reentrancy: Check-Then-Act Across await

Two callers both see nil and both download. Force unwrap crashes.

**Fix:** Capture async result into local. Store in-flight Task handles for dedup.

### 2. Continuation Resumed Zero Times

Callback never fires → caller hangs forever.

**Fix:** Audit every code path. Use `withCheckedThrowingContinuation`. Add timeouts.

### 3. Continuation Resumed Twice

Two callbacks resume same continuation → runtime crash.

**Fix:** Restructure so only one path reaches continuation. Guard with Bool or actor.

### 4. Unstructured Tasks in Loop

No cancellation, no error collection, no await.

**Fix:** `withTaskGroup` / `withThrowingTaskGroup`.

### 5. Swallowed Errors in Task Closures

`Task { try await riskyWork() }` — error silently lost.

**Fix:** Handle inside closure — show alert, log, or propagate via `@State`.

### 6. Blocking Main Actor

CPU work on `@MainActor` causes freezes. More likely in Swift 6.2 (nonisolated stays on caller).

**Fix:** `@concurrent` or `Task.detached` as last resort.

### 7. Unbounded AsyncStream Buffer

High-throughput producer + `.unbounded` = memory growth.

**Fix:** `.bufferingNewest(n)` or `.bufferingOldest(n)`.

### 8. Ignoring CancellationError

Retries or shows alert for normal lifecycle event.

**Fix:**
```swift
do {
    try await loadData()
} catch is CancellationError {
    // Normal — do nothing
} catch {
    self.errorMessage = error.localizedDescription
}
```

### 9. @unchecked Sendable Hiding Races

Class marked `@unchecked Sendable` with unprotected `var` properties.

**Fix:** Use value types, actor, or lock.

## Diagnostics Map

| Diagnostic | Likely Fix |
|-----------|------------|
| "Sending 'x' risks causing data races" | 1) Check region isolation 2) `sending` parameter 3) Make type Sendable 4) `nonisolated(nonsending)` |
| "Static property 'x' is not concurrency-safe" | 1) `@MainActor` annotation 2) Sendable constant 3) `nonisolated(unsafe)` for C interop |
| "Capture of non-Sendable type in @Sendable closure" | 1) Make type Sendable 2) Extract captured values 3) Keep on same actor |
| "Conformance crosses into main actor-isolated code" | 1) `extension X: @MainActor Protocol` 2) Remove type isolation |
| "Expression is 'async' but not marked with 'await'" | Add `await`. If sync context, wrap in `Task {}` |
| "Main actor-isolated conformance cannot be used in nonisolated context" | Move use site onto same actor or remove conformance isolation |

## Migration Patterns

### Completion Handlers → async/await

```swift
func loadUser(id: String) async throws -> User {
    try await withCheckedThrowingContinuation { continuation in
        api.fetchUser(id: id) { result in
            continuation.resume(with: result)
        }
    }
}
```

### DispatchQueue.main.async → @MainActor

```swift
@MainActor
func updateLabel() { label.text = "Done" }
// Called with: await updateLabel()
```

### DispatchQueue.global().async → @concurrent

```swift
@concurrent
func heavyComputation() async -> Result { ... }
```

### Serial DispatchQueue → actor

```swift
actor TokenStore {
    private var token: String?
    func setToken(_ t: String) { token = t }
    func getToken() -> String? { token }
}
```

### Locks → Mutex

`Mutex` preserves checked Sendable on owning type. Prefer over locks when API stays synchronous.

### Combine → AsyncSequence

| Combine | Swift Concurrency |
|---------|-------------------|
| `publisher.sink { }` | `for await value in stream { }` |
| `PassthroughSubject` | `AsyncStream` via `makeStream(of:)` |
| `publisher.values` | Already `AsyncSequence` — use directly |

## Migration Validation Loop

1. **Build** — surface new diagnostics
2. **Fix** — one category at a time (e.g., all Sendable issues first)
3. **Rebuild** — confirm fix compiles cleanly
4. **Test** — run suite to catch regressions
5. **Only proceed** when all diagnostics resolved

## Guardrails

- Do not use `@MainActor` as a blanket fix. Justify why code is truly UI-bound.
- If recommending `@preconcurrency`, `@unchecked Sendable`, or `nonisolated(unsafe)`, require documented safety invariant and removal plan.
- Optimize for smallest safe change. Don't refactor unrelated architecture.
- GCD is still acceptable in low-level libraries, framework interop, and performance-critical synchronous sections.
