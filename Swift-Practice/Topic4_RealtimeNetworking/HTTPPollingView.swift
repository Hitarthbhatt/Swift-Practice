import SwiftUI

// MARK: - Interview: HTTP Polling
// Client repeatedly GETs the server at a fixed interval.
// Pros: simple, works with any server, stateless.
// Cons: wasteful (N clients × freq = server load), stale data between polls, battery drain.
// Variants:
//   • Short-poll  — fixed interval (this demo, 5 s)
//   • Long-poll   — server holds request open until data is ready, then client immediately re-connects
// When to use: low-frequency updates, simple infra, no SSE/WS support needed.

// MARK: - Model

private struct CoinGeckoPrice: Decodable {
    let bitcoin: Bitcoin
    struct Bitcoin: Decodable {
        let usd: Double
    }
}

// MARK: - ViewModel

@Observable
final class HTTPPollingViewModel {
    var priceDisplay: String = "--"
    var priceUSD: Double = 0
    var pollCount: Int = 0
    var isPolling: Bool = false
    var log: [String] = []

    private var pollingTask: Task<Void, Never>?
    // Interview: interval is a key trade-off — shorter = fresher data, higher cost
    private let interval: Duration = .seconds(5)
    private let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd")!

    func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        log.insert("▶️ Polling every 5 s", at: 0)

        pollingTask = Task { @MainActor in
            while !Task.isCancelled {
                await fetchPrice()
                // Interview: Task.sleep respects cancellation — no Timer needed
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
        log.insert("⏹ Stopped after \(pollCount) polls", at: 0)
    }

    private func fetchPrice() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(CoinGeckoPrice.self, from: data)
            let price = response.bitcoin.usd
            priceUSD = price
            priceDisplay = price.formatted(.currency(code: "USD").precision(.fractionLength(0)))
            pollCount += 1
            log.insert("Poll #\(pollCount) → \(priceDisplay)", at: 0)
        } catch {
            log.insert("❌ \(error.localizedDescription)", at: 0)
        }
    }
}

// MARK: - View

struct HTTPPollingView: View {
    @State private var vm = HTTPPollingViewModel()

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("BTC / USD")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.priceDisplay)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.spring, value: vm.priceUSD)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(vm.isPolling ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(vm.isPolling ? "Polling every 5 s" : "Idle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } header: { Text("CoinGecko API") }

            Section {
                // Interview: polling interval is a key trade-off
                // Too short = server load / battery drain
                // Too long = stale data
                Button(vm.isPolling ? "Stop Polling" : "Start Polling") {
                    vm.isPolling ? vm.stopPolling() : vm.startPolling()
                }
                .foregroundStyle(vm.isPolling ? .red : .blue)

                LabeledContent("Total polls", value: "\(vm.pollCount)")
            } header: { Text("Controls") }

            Section {
                ForEach(Array(vm.log.enumerated()), id: \.offset) { _, entry in
                    Text(entry).font(.caption.monospaced())
                }
            } header: { Text("Log (newest first)") }
        }
        .navigationTitle("HTTP Polling")
        .onDisappear { vm.stopPolling() }
    }
}

#Preview {
    NavigationStack { HTTPPollingView() }
}
