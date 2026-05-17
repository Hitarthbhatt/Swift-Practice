import Foundation

// MARK: - Data Race ViewModel (base)
// A data race = two threads access the same memory concurrently,
// at least one is a WRITE, with no synchronization.
//
// counter += 1 compiles to LOAD → ADD → STORE (three non-atomic ops):
//   Thread A: LOAD(5) ─────────────── ADD→6 ── STORE(6)
//   Thread B:          LOAD(5) ─ ADD→6 ──────────────── STORE(6)
//   Result: 6 instead of 7 — one increment lost.
//
// Swift 6 catches this at compile time (Sendable checking).
// Each extension below demonstrates one prevention strategy.

@Observable @MainActor
final class DataRaceViewModel {
    var results: [RaceResult] = []
    var isRunning = false
    let n = 10_000

    func clearResults() { results.removeAll() }
}
