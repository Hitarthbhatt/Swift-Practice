import SwiftUI

struct NetworkInterceptorsView: View {
    @State private var scenarios = InterceptorScenarios.all()
    @State private var expanded: UUID?
    @State private var outputs: [UUID: [String]] = [:]
    @State private var running: UUID?

    var body: some View {
        List(scenarios) { scenario in
            row(scenario)
        }
        .animation(.snappy, value: expanded)
        .animation(.snappy, value: outputs.mapValues { $0.count })
        .navigationTitle("Interceptors")
    }

    @ViewBuilder
    private func row(_ scenario: InterceptorScenario) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(scenario)
            if expanded == scenario.id {
                Text(scenario.detail).font(.callout)
                runButton(scenario)
                output(scenario)
            }
        }
        .padding(.vertical, 4)
    }

    private func header(_ scenario: InterceptorScenario) -> some View {
        Button {
            expanded = (expanded == scenario.id) ? nil : scenario.id
        } label: {
            HStack {
                Text(scenario.title).font(.headline).foregroundStyle(.primary)
                Spacer()
                Image(systemName: expanded == scenario.id ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func runButton(_ scenario: InterceptorScenario) -> some View {
        Button {
            Task {
                running = scenario.id
                outputs[scenario.id] = await scenario.run()
                running = nil
            }
        } label: {
            Label(running == scenario.id ? "Running…" : "Run", systemImage: "play.fill")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(running == scenario.id)
    }

    @ViewBuilder
    private func output(_ scenario: InterceptorScenario) -> some View {
        if let lines = outputs[scenario.id] {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 4)
        }
    }
}

#Preview { NavigationStack { NetworkInterceptorsView() } }
