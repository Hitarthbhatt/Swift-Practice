import Foundation

// MARK: - Old Way 1: Serial DispatchQueue
// A serial queue runs one block at a time — acts as a mutex for the shared var.
// Trade-off: every write pays a GCD dispatch cost; reads are unprotected here.
// Pattern: readers-writers problem → use concurrent queue + barrier for read performance.

extension DataRaceViewModel {
    func runSerialQueue() async {
        isRunning = true
        let actual: Int = await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                var c = 0
                let serial = DispatchQueue(label: "com.demo.serial")
                DispatchQueue.concurrentPerform(iterations: 10_000) { _ in
                    serial.sync { c += 1 }      // only one thread mutates at a time
                }
                cont.resume(returning: c)
            }
        }
        results.append(RaceResult(label: "✅ Serial Queue", expected: n, actual: actual))
        isRunning = false
    }
}
