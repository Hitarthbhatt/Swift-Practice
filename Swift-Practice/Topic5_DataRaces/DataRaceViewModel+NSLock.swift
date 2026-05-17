import Foundation

// MARK: - Old Way 2: NSLock
// Mutual exclusion: only one thread holds the lock at a time, others block.
// withLock { } ensures unlock even if the closure throws — avoids deadlock.
// Pitfall: nesting two locks on the same thread → deadlock.
// NSRecursiveLock allows re-entry from the same thread if needed.

extension DataRaceViewModel {
    func runNSLock() async {
        isRunning = true
        let actual: Int = await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                var c = 0
                let lock = NSLock()
                DispatchQueue.concurrentPerform(iterations: 10_000) { _ in
                    lock.withLock { c += 1 }
                }
                cont.resume(returning: c)
            }
        }
        results.append(RaceResult(label: "✅ NSLock", expected: n, actual: actual))
        isRunning = false
    }
}
