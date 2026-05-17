import SwiftUI

struct NetworkResilienceDemoView: View {
    @State private var vm = NetworkResilienceViewModel()

    var body: some View {
        List {
            failureRateSection

            exponentialSection

            linearSection

            circuitBreakerSection

            oauthSection
        }
        .navigationTitle("Network Resilience")
        .overlay { if vm.isRunning { ProgressView().padding() } }
    }

    // MARK: - Shared failure rate

    private var failureRateSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Mock Failure Rate")
                    Spacer()
                    Text("\(Int(vm.failureRate * 100))%").foregroundStyle(.secondary)
                }
                Slider(value: $vm.failureRate, in: 0...0.95, step: 0.05)
                    .tint(.red)
            }
        } header: { Text("Shared Config") }
        footer: { Text("Probability that each mock network call fails. Set high to see retries trigger.") }
    }

    // MARK: - Exponential Backoff

    private var exponentialSection: some View {
        Section {
            Toggle("Jitter", isOn: $vm.expJitter)
            Button("Run Exponential Backoff") { Task { await vm.runExponential() } }
                .disabled(vm.isRunning)
            logView(vm.expLog)
        } header: { Text("Exponential Backoff") }
        footer: { Text("delay = 1 × 2^attempt. Jitter adds ±30% randomness to prevent thundering herd.") }
    }

    // MARK: - Linear Backoff

    private var linearSection: some View {
        Section {
            Stepper("Base: \(String(format: "%.0f", vm.linBase))s", value: $vm.linBase, in: 0.5...3, step: 0.5)
            Button("Run Linear Backoff") { Task { await vm.runLinear() } }
                .disabled(vm.isRunning)
            logView(vm.linLog)
        } header: { Text("Linear Backoff") }
        footer: { Text("delay = base × attempt. (1s, 2s, 3s…). Predictable; slower growth than exponential.") }
    }

    // MARK: - Circuit Breaker

    private var circuitBreakerSection: some View {
        Section {
            HStack {
                Text("State")
                Spacer()
                Text(vm.cbStateLabel)
                    .bold()
                    .foregroundStyle(stateColor(vm.cbStateColor))
                Circle()
                    .fill(stateColor(vm.cbStateColor))
                    .frame(width: 10, height: 10)
            }
            LabeledContent("Consecutive failures", value: "\(vm.cbFailures)/3")
            HStack(spacing: 12) {
                Button("Send 10 Requests") { Task { await vm.runCircuitBreaker() } }
                    .disabled(vm.isRunning)
                Button("Reset", role: .destructive) { vm.resetBreaker() }
                    .disabled(vm.isRunning)
            }
            logView(vm.cbLog)
        } header: { Text("Circuit Breaker (threshold=3, timeout=8s)") }
        footer: { Text("After 3 failures: Open → rejects immediately. After 8s: Half-Open → probes one request.") }
    }

    // MARK: - OAuth

    private var oauthSection: some View {
        Section {
            LabeledContent("Current Token", value: vm.oauthToken)
                .font(.caption.monospaced())
            LabeledContent("Token Refreshes", value: "\(vm.oauthRefreshCount)")
            Toggle("Simulate Expired (next request → 401)", isOn: $vm.oauthSimulateExpired)
            HStack(spacing: 12) {
                Button("Send Request") {
                    Task { await vm.runOAuthRequest() }
                }
                .disabled(vm.isRunning)
                Button("Expire Token", role: .destructive) { vm.expireOAuthToken() }
                    .disabled(vm.isRunning)
            }
            logView(vm.oauthLog)
        } header: { Text("OAuth Token Refresh Retry") }
        footer: { Text("On 401: refresh token → get new access token → retry once. Refresh is deduped via actor (concurrent 401s share one refresh task).") }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func logView(_ log: [String]) -> some View {
        if !log.isEmpty {
            ForEach(Array(log.prefix(12).enumerated()), id: \.offset) { _, entry in
                Text(entry)
                    .font(.caption.monospaced())
                    .foregroundStyle(logColor(entry))
            }
        }
    }

    private func logColor(_ entry: String) -> Color {
        if entry.hasPrefix("✅") { return .green }
        if entry.hasPrefix("❌") || entry.hasPrefix("🚫") { return .red }
        if entry.hasPrefix("⚠️") || entry.hasPrefix("🔄") { return .orange }
        return .secondary
    }

    private func stateColor(_ name: String) -> Color {
        switch name {
        case "green":  return .green
        case "red":    return .red
        case "orange": return .orange
        default:       return .secondary
        }
    }
}

#Preview {
    NavigationStack { NetworkResilienceDemoView() }
}
