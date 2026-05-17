import SwiftUI

// MARK: - Operation Queue
// Interview: "When would you use OperationQueue over GCD?"
//
// OperationQueue is a higher-level abstraction over GCD.
// Key advantages over raw GCD:
//   - Dependencies between operations (op2 depends on op1)
//   - Cancel individual or all operations
//   - maxConcurrentOperationCount to limit parallelism
//   - KVO observable (isExecuting, isFinished, isCancelled)
//   - Can pause/resume queue
//
// When to use:
//   - GCD: simple fire-and-forget async work
//   - OperationQueue: complex task graphs, cancellation, dependencies
//
// Senior/Staff: Use for download managers, image pipelines, batch processing

class FetchOperation: Operation {
    let id: Int
    var result: String = ""

    init(id: Int) {
        self.id = id
    }

    override func main() {
        // Check cancellation before starting
        guard !isCancelled else { return }

        Thread.sleep(forTimeInterval: Double.random(in: 0.2...0.6))

        guard !isCancelled else {
            result = "Task \(id): cancelled"
            return
        }
        result = "Task \(id): fetched data"
    }
}

struct OperationQueueDemoView: View {
    @State private var log: [String] = []
    @State private var queue = OperationQueue()

    var body: some View {
        List {
            Section("Operation Queue Demos") {
                Button("Dependencies") { demoDependencies() }
                Button("Max Concurrency (2)") { demoMaxConcurrency() }
                Button("Cancel All") { demoCancelAll() }
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
        .navigationTitle("OperationQueue")
    }

    // MARK: - Dependencies: op3 waits for op1 & op2
    private func demoDependencies() {
        log.append("--- Dependencies ---")
        let q = OperationQueue()

        let op1 = BlockOperation {
            Thread.sleep(forTimeInterval: 0.3)
        }
        let op2 = BlockOperation {
            Thread.sleep(forTimeInterval: 0.2)
        }
        let op3 = BlockOperation { [self] in
            DispatchQueue.main.async {
                log.append("op3 ran (after op1 & op2)")
            }
        }

        op1.completionBlock = { [self] in
            DispatchQueue.main.async { log.append("op1 done") }
        }
        op2.completionBlock = { [self] in
            DispatchQueue.main.async { log.append("op2 done") }
        }

        // op3 depends on both op1 and op2
        op3.addDependency(op1)
        op3.addDependency(op2)

        q.addOperations([op1, op2, op3], waitUntilFinished: false)
    }

    // MARK: - Max concurrency
    private func demoMaxConcurrency() {
        log.append("--- Max Concurrency = 2 ---")
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 2

        for i in 1...5 {
            let op = FetchOperation(id: i)
            op.completionBlock = { [self] in
                DispatchQueue.main.async {
                    log.append(op.result)
                }
            }
            q.addOperation(op)
        }
    }

    // MARK: - Cancel all
    private func demoCancelAll() {
        log.append("--- Cancel Demo ---")
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1

        for i in 1...5 {
            let op = FetchOperation(id: i)
            op.completionBlock = { [self] in
                DispatchQueue.main.async { log.append(op.result) }
            }
            q.addOperation(op)
        }

        // Cancel after short delay — queued ops get cancelled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            q.cancelAllOperations()
            log.append("⛔ cancelAllOperations called")
        }
    }
}

#Preview {
    NavigationStack { OperationQueueDemoView() }
}
