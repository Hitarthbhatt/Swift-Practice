import Foundation

// MARK: - New Way 1: Actor
// actor = reference type whose methods run on a serial executor managed by Swift runtime.
// Compiler enforces: you must await any call to an actor from outside its isolation domain.
// No manual locking, no forget-to-unlock bugs, no priority inversion.
// Each `await counter.increment()` enqueues on the actor; no two run simultaneously.

actor SafeCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

extension DataRaceViewModel {
    func runActor() async {
        isRunning = true
        let counter = SafeCounter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<n {
                group.addTask { await counter.increment() }
            }
        }
        let actual = await counter.value
        results.append(RaceResult(label: "✅ Actor", expected: n, actual: actual))
        isRunning = false
    }
}
