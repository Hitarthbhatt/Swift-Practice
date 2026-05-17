import Foundation

// MARK: - Old Way 3: DispatchSemaphore (used as binary mutex)
// value:1 = only one thread may pass wait() at a time → mutual exclusion.
// Primary use-case: rate-limiting (value:N lets N threads through simultaneously).
// Pitfall: forgetting signal() anywhere (including on error paths) → permanent deadlock.
// Prefer NSLock for pure mutual exclusion; semaphore shines for N-resource limiting.

extension DataRaceViewModel {
    func runSemaphore() async {
        isRunning = true
        let actual: Int = await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                var c = 0
                let sem = DispatchSemaphore(value: 1)
                DispatchQueue.concurrentPerform(iterations: 10_000) { _ in
                    sem.wait(); c += 1; sem.signal()
                }
                cont.resume(returning: c)
            }
        }
        results.append(RaceResult(label: "✅ Semaphore", expected: n, actual: actual))
        isRunning = false
    }
}
