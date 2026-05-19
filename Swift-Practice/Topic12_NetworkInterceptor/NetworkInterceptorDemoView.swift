import SwiftUI

struct NetworkInterceptorDemoView: View {
    @State private var vm = NetworkInterceptorViewModel()

    var body: some View {
        List {
            scenarioSection
            runSection
            tokenSection
            logSection
        }
        .navigationTitle("Network Interceptor")
        .overlay { if vm.isRunning { ProgressView().padding() } }
    }

    // MARK: - Scenario picker

    private var scenarioSection: some View {
        Section {
            Picker("Scenario", selection: $vm.scenario) {
                ForEach(NetworkInterceptorViewModel.Scenario.allCases) { scenario in
                    Text(scenario.rawValue).tag(scenario)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: { Text("Scenario") }
        footer: { Text("Picks the mock transport behavior. Same interceptor chain handles all four: adapters inject headers + Bearer; retriers split duties — Auth handles 401, Retry handles 5xx/timeout.") }
    }

    // MARK: - Run

    private var runSection: some View {
        Section {
            HStack(spacing: 12) {
                Button("Send Request") { Task { await vm.sendRequest() } }
                    .disabled(vm.isRunning)
                Button("Expire Token", role: .destructive) {
                    Task { await vm.expireToken() }
                }
                .disabled(vm.isRunning)
                Button("Clear Log") { vm.clearLog() }
                    .disabled(vm.isRunning)
            }
            if !vm.resultBody.isEmpty {
                Text(vm.resultBody)
                    .font(.caption.monospaced())
                    .foregroundStyle(vm.resultBody.hasPrefix("Failed") ? .red : .primary)
            }
        } header: { Text("Run") }
    }

    // MARK: - Auth state

    private var tokenSection: some View {
        Section {
            LabeledContent("Current Token", value: vm.tokenLabel)
                .font(.caption.monospaced())
            LabeledContent("Refreshes", value: "\(vm.refreshCount)")
        } header: { Text("Auth State") }
        footer: { Text("AuthInterceptor adapts every request (Bearer header) and acts as retrier on 401. Refresh is deduped via actor + in-flight Task — concurrent 401s share one refresh.") }
    }

    // MARK: - Event log

    private var logSection: some View {
        Section {
            if vm.log.isEmpty {
                Text("No events yet.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(vm.log.prefix(30).enumerated()), id: \.offset) { _, entry in
                    Text(entry)
                        .font(.caption.monospaced())
                        .foregroundStyle(color(for: entry))
                }
            }
        } header: { Text("Events") }
        footer: { Text("Streamed from LoggingInterceptor (NetworkEventObserver) via AsyncStream. Observer is Sendable; the stream carries lines back to the @MainActor view model.") }
    }

    private func color(for entry: String) -> Color {
        if entry.hasPrefix("→") { return .blue }
        if entry.hasPrefix("←") { return entry.contains("HTTP 2") ? .green : .orange }
        if entry.hasPrefix("✗") { return .red }
        if entry.hasPrefix("⚠️") { return .orange }
        return .secondary
    }
}

#Preview {
    NavigationStack { NetworkInterceptorDemoView() }
}
