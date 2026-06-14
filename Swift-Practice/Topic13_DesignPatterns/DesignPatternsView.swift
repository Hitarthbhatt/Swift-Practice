import SwiftUI

struct DesignPatternsView: View {
    @State private var demos = DesignPatternLibrary.all()
    @State private var expanded: UUID?
    @State private var outputs: [UUID: [String]] = [:]
    @State private var running: UUID?

    var body: some View {
        List(demos) { demo in
            row(demo)
        }
        .animation(.snappy, value: expanded)
        .animation(.snappy, value: outputs.mapValues { $0.count })
        .navigationTitle("Design Patterns")
    }

    @ViewBuilder
    private func row(_ demo: PatternDemo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(demo)
            if expanded == demo.id {
                Text(demo.scenario).font(.callout)
                runButton(demo)
                output(demo)
            }
        }
        .padding(.vertical, 4)
    }

    private func header(_ demo: PatternDemo) -> some View {
        Button {
            expanded = (expanded == demo.id) ? nil : demo.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(demo.name).font(.headline)
                    Text(demo.intent).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: expanded == demo.id ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func runButton(_ demo: PatternDemo) -> some View {
        Button {
            Task {
                running = demo.id
                outputs[demo.id] = await demo.run()
                running = nil
            }
        } label: {
            Label(running == demo.id ? "Running…" : "Run", systemImage: "play.fill")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(running == demo.id)
    }

    @ViewBuilder
    private func output(_ demo: PatternDemo) -> some View {
        if let lines = outputs[demo.id] {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Label(line, systemImage: "arrow.right.circle.fill")
                        .font(.caption.monospaced())
                        .foregroundStyle(.green)
                }
            }
            .padding(.leading, 4)
        }
    }
}

#Preview { NavigationStack { DesignPatternsView() } }
