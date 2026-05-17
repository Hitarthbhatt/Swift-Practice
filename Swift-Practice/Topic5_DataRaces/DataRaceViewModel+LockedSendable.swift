import Foundation

// MARK: - New Way 3: @unchecked Sendable + NSLock
// Sendable = safe to pass across concurrency boundaries (tasks / actors).
// @unchecked = "compiler, trust me — I handle thread safety manually."
// Use when: wrapping C/ObjC types, legacy code, or when actor overhead is unacceptable.
// Risk: compiler won't catch mistakes — every access must be manually locked.

final class LockedCounter: @unchecked Sendable {
    private var _value = 0
    private let lock = NSLock()
    var value: Int { lock.withLock { _value } }
    func increment() { lock.withLock { _value += 1 } }
}

extension DataRaceViewModel {
    func runLockedSendable() async {
        isRunning = true
        let counter = LockedCounter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<n {
                group.addTask { counter.increment() }
            }
        }
        results.append(RaceResult(label: "✅ @unchecked Sendable", expected: n, actual: counter.value))
        isRunning = false
    }
}
