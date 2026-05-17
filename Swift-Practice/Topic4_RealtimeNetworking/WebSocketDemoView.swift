import SwiftUI

// MARK: - Interview: WebSockets
// WebSocket = full-duplex, persistent TCP connection upgraded from HTTP (101 Switching Protocols).
// Client sends messages AND receives messages on the same connection.
// Pros: low latency, bi-directional, less overhead per message than HTTP.
// Cons: stateful (server must track connections), trickier to load-balance, no automatic reconnect.
// When to use: chat, collaborative editing, live trading, gaming — anything bidirectional/low-latency.
// iOS API: URLSessionWebSocketTask (iOS 13+), send()/receive() are async.
// Ping/Pong: built into protocol for keep-alive detection.

// MARK: - Model

struct BinanceTrade: Decodable {
    let s: String   // symbol
    let p: String   // price
    let q: String   // quantity
    let T: Int64    // trade time ms
    let m: Bool     // buyer is market maker (sell-side aggressor if false)

    var priceDouble: Double { Double(p) ?? 0 }
    var quantityDouble: Double { Double(q) ?? 0 }
    var side: String { m ? "SELL" : "BUY" }
    var sideColor: Color { m ? .red : .green }
    var tradeDate: Date { Date(timeIntervalSince1970: Double(T) / 1000) }
    var timeLabel: String { tradeDate.formatted(.dateTime.hour().minute().second(.defaultDigits)) }
}

struct TradeEntry: Identifiable {
    let id: UUID = UUID()
    let trade: BinanceTrade
}

// MARK: - ViewModel

@Observable
final class WebSocketViewModel {
    var trades: [TradeEntry] = []
    var latestPrice: String = "--"
    var isConnected: Bool = false
    var status: String = "Disconnected"
    var messageCount: Int = 0

    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?

    // Binance aggTrade stream — free, no API key, extremely stable
    // aggTrade aggregates consecutive fills from the same order for cleaner data
    private let url = URL(string: "wss://stream.binance.com:9443/ws/btcusdt@aggTrade")!

    func connect() {
        guard !isConnected else { return }
        status = "Connecting…"

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        isConnected = true
        status = "Connected"

        startReceiving()
        startPing()
    }

    func disconnect() {
        pingTask?.cancel()
        receiveTask?.cancel()
        // Interview: close code 1000 = normal closure per RFC 6455
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        status = "Disconnected"
    }

    func sendPing() {
        // Interview: ping/pong is used for keep-alive; server replies with pong automatically
        webSocketTask?.sendPing { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.status = "Ping failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Private

    private func startReceiving() {
        receiveTask = Task { @MainActor in
            while !Task.isCancelled, isConnected {
                await receiveMessage()
            }
        }
    }

    @MainActor
    private func receiveMessage() async {
        guard let task = webSocketTask else { return }
        do {
            // Interview: receive() suspends until the next message arrives
            let message = try await task.receive()
            messageCount += 1

            switch message {
            case .string(let text):
                parseTrade(text)
            case .data(let data):
                if let text = String(data: data, encoding: .utf8) { parseTrade(text) }
            @unknown default:
                break
            }
        } catch {
            if isConnected {
                status = "❌ \(error.localizedDescription)"
                isConnected = false
            }
        }
    }

    private func parseTrade(_ text: String) {
        guard
            let data = text.data(using: .utf8),
            let trade = try? JSONDecoder().decode(BinanceTrade.self, from: data)
        else { return }

        latestPrice = trade.priceDouble.formatted(.currency(code: "USD").precision(.fractionLength(2)))
        trades.insert(TradeEntry(trade: trade), at: 0)
        if trades.count > 50 { trades.removeLast() }
    }

    private func startPing() {
        // Interview: send ping every 30 s to prevent proxy/NAT timeout (typical timeout ~60 s)
        pingTask = Task { @MainActor in
            while !Task.isCancelled, isConnected {
                try? await Task.sleep(for: .seconds(30))
                sendPing()
            }
        }
    }
}

// MARK: - View

struct WebSocketDemoView: View {
    @State private var vm = WebSocketViewModel()

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("BTC / USDT")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.latestPrice)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.2), value: vm.latestPrice)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(vm.isConnected ? .green : .gray)
                            .frame(width: 8, height: 8)
                        Text(vm.status)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } header: { Text("Binance Live Trades") }

            Section {
                Button(vm.isConnected ? "Disconnect" : "Connect") {
                    vm.isConnected ? vm.disconnect() : vm.connect()
                }
                .foregroundStyle(vm.isConnected ? .red : .blue)

                LabeledContent("Messages received", value: "\(vm.messageCount)")

                Button("Send Ping") { vm.sendPing() }
                    .disabled(!vm.isConnected)
                    .foregroundStyle(.secondary)
            } header: { Text("Controls") }

            Section {
                if vm.trades.isEmpty {
                    Text("No trades yet — tap Connect")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(vm.trades) { entry in
                        HStack {
                            Text(entry.trade.side)
                                .font(.caption.bold())
                                .foregroundStyle(entry.trade.sideColor)
                                .frame(width: 38, alignment: .leading)
                            Text(entry.trade.priceDouble.formatted(.number.precision(.fractionLength(2))))
                                .font(.caption.monospaced())
                                .frame(width: 90, alignment: .trailing)
                            Text("×")
                                .foregroundStyle(.secondary)
                                .font(.caption2)
                            Text(entry.trade.quantityDouble.formatted(.number.precision(.fractionLength(5))))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.trade.timeLabel)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } header: { Text("Trade Feed (last 50)") }
        }
        .navigationTitle("WebSockets")
        .onDisappear { vm.disconnect() }
    }
}

#Preview {
    NavigationStack { WebSocketDemoView() }
}
