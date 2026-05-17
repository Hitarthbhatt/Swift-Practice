import Foundation

// MARK: - Problem: Unprotected (Data Race)
// No synchronization → concurrent RMW on the same var → lost increments.
// Swift 6 compile error: "mutation of captured var 'c' in concurrently-executing code"

extension DataRaceViewModel {
    func runUnsafe() async {
        isRunning = true
        let actual: Int = await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                var c = 0
                DispatchQueue.concurrentPerform(iterations: 10_000) { _ in
                    c += 1      // ← DATA RACE: non-atomic LOAD→ADD→STORE
                }
                cont.resume(returning: c)
            }
        }
        results.append(RaceResult(label: "❌ Unprotected", expected: n, actual: actual))
        isRunning = false
    }
}
