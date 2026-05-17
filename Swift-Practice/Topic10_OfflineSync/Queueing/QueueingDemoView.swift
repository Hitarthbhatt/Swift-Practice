import SwiftUI
import SwiftData

// MARK: - Persistent Operation Queue Demo
//
// Outer view owns the SwiftData container (scoped just to this topic so the
// rest of the app stays free of SwiftData setup). Inner view reads the
// context from the environment and constructs the view model once.

struct QueueingDemoView: View {
    var body: some View {
        QueueingContentView()
            .modelContainer(for: SyncOperation.self)
    }
}

// MARK: - Content

private struct QueueingContentView: View {
    @Environment(\.modelContext) private var context
    @State private var vm: QueueingViewModel?

    var body: some View {
        Group {
            if let vm {
                loaded(vm: vm)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Persistent Op Queue")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if vm == nil {
                let newVM = QueueingViewModel(context: context)
                vm = newVM
                await newVM.bind()
            }
        }
    }

    @ViewBuilder
    private func loaded(vm: QueueingViewModel) -> some View {
        @Bindable var vm = vm
        List {
            countsSection(vm: vm)
            actionsSection(vm: vm)
            failureRateSection(vm: vm)
            operationsSection(vm: vm)
            logSection(vm: vm)
            explainerSection
        }
    }

    // MARK: - Sections

    private func countsSection(vm: QueueingViewModel) -> some View {
        Section {
            HStack(spacing: 12) {
                countPill("Pending", value: vm.counts.pending, color: .blue)
                countPill("In-flight", value: vm.counts.inflight, color: .purple)
                countPill("Failed", value: vm.counts.failed, color: .orange)
                countPill("Dead", value: vm.counts.dead, color: .red)
            }
            .frame(maxWidth: .infinity)
        } header: {
            Text("Queue State")
        } footer: {
            Text("Persisted to SwiftData. Relaunch the app with pending ops to see crash recovery reset in-flight rows back to pending.")
        }
    }

    private func actionsSection(vm: QueueingViewModel) -> some View {
        Section {
            HStack(spacing: 10) {
                Button {
                    vm.enqueueRandom()
                } label: {
                    Label("Enqueue 1", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    vm.enqueueBurst()
                } label: {
                    Label("Burst × 10", systemImage: "square.stack.3d.up")
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                Button {
                    vm.togglePause()
                } label: {
                    Label(
                        vm.isPaused ? "Go Online" : "Go Offline",
                        systemImage: vm.isPaused ? "wifi" : "wifi.slash"
                    )
                }
                .buttonStyle(.bordered)
                .tint(vm.isPaused ? .green : .orange)

                Button {
                    vm.retryAllFailed()
                } label: {
                    Label("Retry Failed", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(vm.counts.failed == 0)
            }

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    vm.clearDead()
                } label: {
                    Label("Clear Dead", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(vm.counts.dead == 0)

                Button(role: .destructive) {
                    vm.clearAll()
                } label: {
                    Label("Clear All", systemImage: "xmark.bin")
                }
                .buttonStyle(.bordered)
                .disabled(vm.counts.total == 0)
            }
        } header: {
            Text("Actions")
        } footer: {
            Text("Go Offline pauses dispatch — enqueues pile up as pending. Go Online resumes and you'll see per-entity FIFO: two ops on the same note run strictly in order while other notes run in parallel (up to 3 workers).")
        }
    }

    private func failureRateSection(vm: QueueingViewModel) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Server failure rate")
                    Spacer()
                    Text("\(Int(vm.failureRate * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { vm.failureRate },
                        set: { vm.setFailureRate($0) }
                    ),
                    in: 0...0.95,
                    step: 0.05
                )
                .tint(.red)
            }
        } header: {
            Text("Server Config")
        } footer: {
            Text("Simulates a flaky backend. The server dedupes on idempotency key (the op's UUID) so retried ops don't double-apply — you'll see ‘(server dedup)’ in the log when a retry lands on a key the server already saw.")
        }
    }

    private func operationsSection(vm: QueueingViewModel) -> some View {
        Section {
            if vm.operations.isEmpty {
                Text("No operations queued")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(vm.operations) { op in
                    operationRow(op)
                }
            }
        } header: {
            Text("Operations (\(vm.operations.count))")
        }
    }

    private func logSection(vm: QueueingViewModel) -> some View {
        Section {
            if vm.log.isEmpty {
                Text("No events yet")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(Array(vm.log.prefix(30).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption.monospaced())
                        .foregroundStyle(logColor(line))
                }
            }
        } header: {
            Text("Log")
        }
    }

    private var explainerSection: some View {
        Section {
            Text("""
                • Every op has a client-generated UUID (idempotency key) persisted to SwiftData.
                • On failure: attempt++ and wait 1.5s before re-pending. After 5 attempts: DEAD.
                • Per-entity FIFO: two ops on note-A never run in parallel — the second waits.
                • Cross-entity parallelism: up to 3 workers across different entities.
                • Crash recovery: on start, any stale `inflight` rows are reset to `pending` — safe thanks to idempotency keys.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("How it works")
        }
    }

    // MARK: - Helpers

    private func countPill(_ label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private func operationRow(_ op: OperationSummary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(op.kind.symbol)
                .font(.title3)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(op.entityId)
                        .font(.subheadline.bold())
                    Text(op.id.uuidString.prefix(8))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
                if let err = op.lastError {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                stateBadge(op.state)
                if op.attempts > 0 {
                    Text("attempt \(op.attempts)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func stateBadge(_ state: SyncOperationState) -> some View {
        let color: Color = {
            switch state {
            case .pending:  return .blue
            case .inflight: return .purple
            case .failed:   return .orange
            case .dead:     return .red
            }
        }()
        return Text(state.label)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private func logColor(_ line: String) -> Color {
        if line.hasPrefix("✅") { return .green }
        if line.hasPrefix("❌") || line.hasPrefix("💀") { return .red }
        if line.hasPrefix("🔄") || line.hasPrefix("♻️") { return .orange }
        if line.hasPrefix("📤") { return .purple }
        if line.hasPrefix("➕") { return .blue }
        if line.hasPrefix("⏸️") || line.hasPrefix("▶️") { return .indigo }
        return .secondary
    }
}

#Preview {
    NavigationStack { QueueingDemoView() }
}
