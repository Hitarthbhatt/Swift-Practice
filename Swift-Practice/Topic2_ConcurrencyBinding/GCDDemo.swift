import SwiftUI

// MARK: - GCD (Grand Central Dispatch)
// Interview: "Explain GCD and its queue types"
//
// GCD is a C-based API for concurrent programming.
// Queues:
//   - Main queue: serial, UI work only (DispatchQueue.main)
//   - Global queues: concurrent, system-provided, 4 QoS levels
//   - Custom queues: serial by default, can be concurrent
//
// QoS Priority (high → low):
//   .userInteractive > .userInitiated > .default > .utility > .background
//
// sync vs async:
//   - sync: blocks calling thread until work completes
//   - async: returns immediately, work executes later
//
// ⚠️ NEVER call sync on main queue from main thread → deadlock
//
// Senior/Staff:
//   - Dispatch barriers for thread-safe read/write
//   - DispatchGroup for waiting on multiple async tasks
//   - DispatchSemaphore for limiting concurrency
//   - DispatchWorkItem for cancellable work

struct GCDDemoView: View {
    @State private var log: [String] = []
    @State private var isRunning = false

    var body: some View {
        List {
            Section("GCD Demos") {
                Button("Serial vs Concurrent Queue") { demoSerialVsConcurrent() }
                Button("DispatchGroup") { demoDispatchGroup() }
                Button("Barrier (Reader-Writer)") { demoBarrier() }
                Button("Semaphore (Limit Concurrency)") { demoSemaphore() }
                Button("Clear Log") { log.removeAll() }
            }

            Section("Log") {
                if log.isEmpty {
                    Text("Tap a demo above").foregroundStyle(.secondary)
                }
                ForEach(Array(log.enumerated()), id: \.offset) { _, entry in
                    Text(entry).font(.caption.monospaced())
                }
            }
        }
        .navigationTitle("GCD")
    }

    // MARK: - Serial vs Concurrent
    private func demoSerialVsConcurrent() {
        log.append("--- Serial vs Concurrent ---")

        // Serial queue: tasks execute one at a time, in order
        let serialQueue = DispatchQueue(label: "com.demo.serial")
        // Concurrent queue: tasks can run simultaneously
        let concurrentQueue = DispatchQueue(label: "com.demo.concurrent", attributes: .concurrent)

        for i in 1...3 {
            serialQueue.async { [self] in
                let result = "Serial task \(i) on \(Thread.current)"
                DispatchQueue.main.async { log.append(result) }
            }
        }
        for i in 1...3 {
            concurrentQueue.async { [self] in
                let result = "Concurrent task \(i) on \(Thread.current)"
                DispatchQueue.main.async { log.append(result) }
            }
        }
    }

    // MARK: - DispatchGroup: wait for multiple async tasks
    private func demoDispatchGroup() {
        log.append("--- DispatchGroup ---")
        let group = DispatchGroup()

        for i in 1...3 {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                Thread.sleep(forTimeInterval: Double.random(in: 0.1...0.5))
                DispatchQueue.main.async { log.append("Task \(i) done") }
                group.leave()
            }
        }

        // Notify on main thread when ALL tasks complete
        group.notify(queue: .main) { [self] in
            log.append("✅ All group tasks finished")
        }
    }

    // MARK: - Barrier: thread-safe read/write (Reader-Writer pattern)
    private func demoBarrier() {
        log.append("--- Barrier (Reader-Writer) ---")
        let rwQueue = DispatchQueue(label: "com.demo.rw", attributes: .concurrent)
        var sharedResource = 0

        // Multiple concurrent reads are safe
        for i in 1...3 {
            rwQueue.async { [self] in
                let val = sharedResource
                DispatchQueue.main.async { log.append("Read \(i): \(val)") }
            }
        }

        // Write uses barrier — exclusive access, no concurrent reads during write
        rwQueue.async(flags: .barrier) { [self] in
            sharedResource = 42
            DispatchQueue.main.async { log.append("Write: set to 42 (barrier)") }
        }

        // Reads after barrier see updated value
        rwQueue.async { [self] in
            let val = sharedResource
            DispatchQueue.main.async { log.append("Read after barrier: \(val)") }
        }
    }

    // MARK: - Semaphore: limit concurrent access
    private func demoSemaphore() {
        log.append("--- Semaphore (max 2 concurrent) ---")
        let semaphore = DispatchSemaphore(value: 2) // allow max 2 at a time

        for i in 1...5 {
            DispatchQueue.global().async { [self] in
                semaphore.wait() // decrement, block if 0
                DispatchQueue.main.async { log.append("Task \(i) started") }
                Thread.sleep(forTimeInterval: 0.3)
                DispatchQueue.main.async { log.append("Task \(i) done") }
                semaphore.signal() // increment, unblock waiting
            }
        }
    }
}

#Preview {
    NavigationStack { GCDDemoView() }
}
