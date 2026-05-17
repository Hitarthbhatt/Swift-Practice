import SwiftUI

struct DataRaceDemoView: View {
    @State private var vm = DataRaceViewModel()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("counter += 1 is three ops: LOAD → ADD → STORE. Two threads interleaving on the same variable = lost increments.")
                        .font(.caption)
                    Text("Expected: \(vm.n)   Actual (race): ???")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                runButton("Run Unprotected (Race)") { await vm.runUnsafe() }
            } header: { Text("The Problem — Wrong Value") }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Concurrent Array.append() triggers buffer reallocation. Two threads both reallocate → one frees memory the other is reading → EXC_BAD_ACCESS.")
                        .font(.caption)
                    Text("Wrong values are the lucky case. This is the unlucky one.")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
                .padding(.vertical, 2)
                Button("💥 Crash the App (Array Race)") {
                    vm.runCrashingArrayRace()
                }
                .foregroundStyle(.red)
            } header: { Text("The Problem — Crash (Memory Corruption)") }
            footer: { Text("Tap only when attached to the debugger. You will see EXC_BAD_ACCESS or SIGABRT.") }

            Section {
                runButton("Serial DispatchQueue") { await vm.runSerialQueue() }
                runButton("NSLock")               { await vm.runNSLock() }
                runButton("DispatchSemaphore")    { await vm.runSemaphore() }
            } header: { Text("Old Ways (GCD Era)") }

            Section {
                runButton("Actor")                { await vm.runActor() }
                runButton("@MainActor class")     { await vm.runMainActor() }
                runButton("@unchecked Sendable")  { await vm.runLockedSendable() }
            } header: { Text("New Ways (Swift Concurrency)") }
              footer: { Text("Swift 6: mutating a captured var in a concurrent closure is a compile error. Actors + Sendable make data races impossible to express.") }

            if !vm.results.isEmpty {
                Section {
                    ForEach(vm.results) { r in
                        HStack(spacing: 10) {
                            Image(systemName: r.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(r.passed ? Color.green : Color.red)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(r.label).font(.caption.bold())
                                Text("got \(r.actual) / expected \(r.expected)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(r.passed ? Color.green : Color.red)
                            }
                        }
                    }
                    Button("Clear", role: .destructive) { vm.clearResults() }
                } header: { Text("Results") }
            }
        }
        .navigationTitle("Data Races")
        .overlay { if vm.isRunning { ProgressView("Running \(vm.n) increments…") } }
    }

    @ViewBuilder
    private func runButton(_ label: String, action: @escaping () async -> Void) -> some View {
        Button(label) { Task { await action() } }
            .disabled(vm.isRunning)
    }
}

#Preview {
    NavigationStack { DataRaceDemoView() }
}
