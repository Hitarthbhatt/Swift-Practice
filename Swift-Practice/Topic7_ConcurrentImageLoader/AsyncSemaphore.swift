import Foundation

// MARK: - AsyncSemaphore
// Counting semaphore for Swift Concurrency — limits N concurrent async operations.
// Classic OS semaphore (P/V = wait/signal) re-implemented with actors + continuations.
//
// Interview: Why not DispatchSemaphore?
//   DispatchSemaphore.wait() BLOCKS the thread — illegal on the cooperative thread pool
//   (can exhaust threads → deadlock). AsyncSemaphore suspends the Task, not the thread.
//
// How it works:
//   available > 0 → decrement and proceed immediately (fast path)
//   available == 0 → store continuation in queue; Task suspends until signal() resumes it

actor AsyncSemaphore {
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        precondition(limit > 0)
        available = limit
    }

    /// Acquires a slot. Suspends if none are available.
    func wait() async {
        if available > 0 {
            available -= 1
        } else {
            await withCheckedContinuation { waiters.append($0) }
        }
    }

    /// Releases a slot. Resumes the longest-waiting caller if any.
    func signal() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()          // passes slot directly — available stays the same
        } else {
            available += 1
        }
    }

    var slotsAvailable: Int { available }
    var waitingCount: Int { waiters.count }
}
