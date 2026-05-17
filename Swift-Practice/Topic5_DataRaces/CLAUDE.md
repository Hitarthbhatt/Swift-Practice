# Topic 5 — Data Races

Same counter problem, 8 mitigation strategies. Single ViewModel split via extensions.

## Files
- `DataRaceViewModel.swift` — base `@Observable` VM, shared state.
- `RaceResult.swift` — result model.
- `DataRaceDemoView.swift` — UI runs each strategy, shows race vs safe.

## Strategy extensions
- `+Unprotected.swift` — bare `counter += 1` → lost updates.
- `+CrashingRace.swift` — race on reference type → crash.
- `+SerialQueue.swift` — `DispatchQueue` serial sync.
- `+NSLock.swift` — manual `lock()`/`unlock()`.
- `+Semaphore.swift` — `DispatchSemaphore(value: 1)`.
- `+Actor.swift` — `actor` isolation.
- `+MainActor.swift` — `@MainActor` global isolation.
- `+LockedSendable.swift` — `@unchecked Sendable` + internal lock.

## Takeaway
Actor = preferred. Locks/queues = legacy / non-Swift-Concurrency code.
