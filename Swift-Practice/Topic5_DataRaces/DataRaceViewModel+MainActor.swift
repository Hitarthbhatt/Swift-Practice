import Foundation

// MARK: - New Way 2: @MainActor
// @MainActor pins a type to the main thread's serial executor.
// All tasks that touch the counter must hop to the main thread → single-threaded → no race.
// Cost: context switches from background tasks to main thread (fine for UI state,
//       avoid for CPU-heavy computation — use a regular actor instead).

@MainActor
final class MainActorCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

extension DataRaceViewModel {
    func runMainActor() async {
        isRunning = true
        let counter = MainActorCounter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<n {
                group.addTask { @MainActor in counter.increment() }
            }
        }
        results.append(RaceResult(label: "✅ @MainActor", expected: n, actual: counter.value))
        isRunning = false
    }
}
