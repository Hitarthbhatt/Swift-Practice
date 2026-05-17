import SwiftUI

// MARK: - Interview: Server-Sent Events (SSE)
// SSE = one HTTP connection held open; server pushes events as text/event-stream.
// Protocol: lines of "field: value", events separated by blank lines.
//   data: <payload>          — event payload (required)
//   id: <string>             — sets Last-Event-ID for reconnect
//   event: <type>            — custom event type
//   retry: <ms>              — client reconnect delay
// Pros: simpler than WS, native browser EventSource API, works over HTTP/2, auto-reconnect.
// Cons: server → client only (half-duplex), text-only, no binary.
// When to use: live feeds, dashboards, notifications — anything read-only from client side.
// iOS: no native EventSource — use URLSession bytes(from:) async API to stream lines.

// MARK: - Model

struct SSEEvent: Identifiable {
    let id: UUID = UUID()
    let rawData: String
    let receivedAt: Date = Date()

    var timeLabel: String {
        receivedAt.formatted(.dateTime.hour().minute().second())
    }
}

// MARK: - ViewModel

@Observable
final class SSEViewModel {
    var events: [SSEEvent] = []
    var isConnected: Bool = false
    var status: String = "Disconnected"
    var eventCount: Int = 0

    private var streamTask: Task<Void, Never>?

    // sse.dev/test — public SSE endpoint, sends an event every ~1 s
    private let url = URL(string: "https://sse.dev/test")!

    func connect() {
        guard !isConnected else { return }
        isConnected = true
        status = "Connecting…"

        streamTask = Task { @MainActor in
            await readSSEStream()
        }
    }

    func disconnect() {
        streamTask?.cancel()
        streamTask = nil
        isConnected = false
        status = "Disconnected"
    }

    @MainActor
    private func readSSEStream() async {
        var request = URLRequest(url: url)
        // Interview: Accept header signals SSE capability to the server
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        // Interview: Cache-Control prevents proxy caching the stream
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                status = "❌ Bad response"
                isConnected = false
                return
            }

            status = "Connected"
            var dataBuffer: String = ""

            // Interview: iterate async byte lines — each "data: ..." line is one field
            for try await line in asyncBytes.lines {
                if Task.isCancelled { break }

                if line.hasPrefix("data:") {
                    // Strip "data:" prefix; trim leading space per spec
                    dataBuffer = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    events.insert(SSEEvent(rawData: dataBuffer), at: 0)
                    eventCount += 1
                    if events.count > 50 { events.removeLast() }
                    dataBuffer = ""
                }
                // Other fields (id:, event:, retry:) skipped for brevity
            }
        } catch is CancellationError {
            // normal disconnect
        } catch {
            status = "❌ \(error.localizedDescription)"
        }

        isConnected = false
        if status == "Connected" { status = "Disconnected" }
    }
}

// MARK: - View

struct SSEDemoView: View {
    @State private var vm = SSEViewModel()

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(vm.isConnected ? .green : .gray)
                            .frame(width: 10, height: 10)
                            .animation(.easeInOut(duration: 0.3), value: vm.isConnected)
                        Text(vm.status)
                            .font(.subheadline.weight(.medium))
                    }
                    Text("\(vm.eventCount) events received")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } header: { Text("sse.dev/test") }

            Section {
                Button(vm.isConnected ? "Disconnect" : "Connect") {
                    vm.isConnected ? vm.disconnect() : vm.connect()
                }
                .foregroundStyle(vm.isConnected ? .red : .blue)
            } header: { Text("Controls") }

            Section {
                if vm.events.isEmpty {
                    Text("No events yet — tap Connect")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(vm.events) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.rawData)
                                .font(.caption.monospaced())
                                .lineLimit(3)
                            Text(event.timeLabel)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } header: { Text("Events (newest first, max 50)") }
        }
        .navigationTitle("Server-Sent Events")
        .onDisappear { vm.disconnect() }
    }
}

#Preview {
    NavigationStack { SSEDemoView() }
}
