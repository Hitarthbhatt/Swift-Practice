import Foundation

// MARK: - Crashing Data Race: Concurrent Array Mutation
//
// The counter demo showed WRONG VALUES — a logic bug.
// This shows a CRASH — a memory corruption bug.
//
// Swift Array is a value type backed by a heap buffer.
// append() may trigger a buffer reallocation (copy-on-grow):
//   1. Allocate new buffer (2× capacity)
//   2. Copy existing elements
//   3. Free old buffer
//   4. Write new element
//
// If two threads both see capacity=full and both reallocate:
//   Thread A frees old buffer → Thread B reads freed memory → EXC_BAD_ACCESS
//   Thread A writes count=N   → Thread B writes count=N     → double-write corruption
//
// Result: guaranteed crash within ~100–1000 iterations.
// This is WHY collections need synchronization — wrong values are the lucky case.

extension DataRaceViewModel {
    // WARNING: intentionally crashes the app to demonstrate memory corruption.
    // Run only when you want to see the crash in the debugger.
    func runCrashingArrayRace() {
        var array = [Int]()
        // No synchronization — concurrent appends corrupt the buffer
        let serial = DispatchQueue(label: "com.demo.serial", attributes: .concurrent)
        DispatchQueue.concurrentPerform(iterations: 1_000) { i in
            serial.async(flags: .barrier) { array.append(i) }    // ← EXC_BAD_ACCESS / SIGABRT
        }
        
        // Unreachable — crash occurs before this line
        results.append(RaceResult(label: "✅ Crashing Array", expected: 1_000, actual: array.count))
    }
}
