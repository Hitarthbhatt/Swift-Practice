import SwiftUI

// MARK: - Swift Concurrency: async/await, Tasks, Structured Concurrency
// Interview: "Explain Swift's structured concurrency model"
//
// async/await (Swift 5.5+):
//   - async marks a function that can suspend
//   - await marks a suspension point
//   - Compiler enforces correct usage (no forgotten awaits)
//
// Task:
//   - Unit of async work
//   - Task { } — unstructured, inherits actor context
//   - Task.detached { } — unstructured, does NOT inherit actor
//   - task group — structured, child tasks bound to parent scope
//
// Structured Concurrency:
//   - async let — concurrent bindings (like Promise.all)
//   - TaskGroup — dynamic number of concurrent tasks
//   - Cancellation propagates from parent to children
//   - Parent waits for all children before returning
//
// Senior/Staff:
//   - Understand task tree and cancellation propagation
//   - Know when to use structured vs unstructured tasks
//   - Task priorities and priority inversion
//   - Continuations for bridging callback-based APIs

struct AsyncAwaitDemoView: View {
    @State private var log: [String] = []
    @State private var isLoading = false

    var body: some View {
        List {
            Section("async/await Demos") {
                Button("Basic async/await") { Task { await demoBasicAsync() } }
                Button("async let (parallel)") { Task { await demoAsyncLet() } }
                Button("TaskGroup") { Task { await demoTaskGroup() } }
                Button("Task Cancellation") { Task { await demoCancellation() } }
                Button("Bridge Callback → async") { Task { await demoContinuation() } }
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
        .navigationTitle("async/await")
    }

    // MARK: - Basic: sequential async calls
    private func demoBasicAsync() async {
        log.append("--- Basic async/await ---")
        let start = CFAbsoluteTimeGetCurrent()

        // These run sequentially — each await suspends until complete
        let a = await fetchData(id: 1)
        let b = await fetchData(id: 2)

        let elapsed = String(format: "%.2fs", CFAbsoluteTimeGetCurrent() - start)
        log.append("\(a), \(b) (sequential: \(elapsed))")
    }

    // MARK: - async let: run in parallel, await together
    private func demoAsyncLet() async {
        log.append("--- async let (parallel) ---")
        let start = CFAbsoluteTimeGetCurrent()

        // Both start immediately, run concurrently
        async let a = fetchData(id: 1)
        async let b = fetchData(id: 2)
        async let c = fetchData(id: 3)

        // Await all results — like Promise.all
        let results = await [a, b, c]
        let elapsed = String(format: "%.2fs", CFAbsoluteTimeGetCurrent() - start)
        log.append("\(results.joined(separator: ", ")) (parallel: \(elapsed))")
    }

    // MARK: - TaskGroup: dynamic number of concurrent tasks
    private func demoTaskGroup() async {
        log.append("--- TaskGroup ---")

        let results = await withTaskGroup(of: String.self) { group in
            for i in 1...5 {
                group.addTask {
                    await fetchData(id: i)
                }
            }

            var collected: [String] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        log.append("Results: \(results.joined(separator: ", "))")
    }

    // MARK: - Cancellation: cooperative cancellation
    private func demoCancellation() async {
        log.append("--- Cancellation ---")

        let task = Task {
            for i in 1...10 {
                // Cooperative: must check for cancellation
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(100))
                await MainActor.run { log.append("Step \(i)") }
            }
            return "Completed all steps"
        }

        // Cancel after 300ms
        try? await Task.sleep(for: .milliseconds(300))
        task.cancel()
        log.append("⛔ Task cancelled")

        do {
            let result = try await task.value
            log.append(result)
        } catch {
            log.append("Task threw: \(error)")
        }
    }

    // MARK: - Continuation: bridge callback API → async
    private func demoContinuation() async {
        log.append("--- Continuation ---")

        let result = await withCheckedContinuation { continuation in
            // Simulating a callback-based API
            legacyFetchWithCallback(id: 99) { data in
                continuation.resume(returning: data)
                // ⚠️ Must resume exactly once — crash if called twice or never
            }
        }

        log.append("Bridged result: \(result)")
    }

    // MARK: - Helpers

    private func fetchData(id: Int) async -> String {
        try? await Task.sleep(for: .milliseconds(Int.random(in: 200...500)))
        return "Data(\(id))"
    }

    private func legacyFetchWithCallback(id: Int, completion: @escaping (String) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            completion("Legacy(\(id))")
        }
    }
}

#Preview {
    NavigationStack { AsyncAwaitDemoView() }
}
