import SwiftUI

struct TestingDemoView: View {
    @State private var suite = MiniTest()
    @State private var running = false

    var body: some View {
        List {
            Section {
                Button {
                    Task {
                        running = true
                        suite.reset()
                        await CartTests.runAll(into: suite)
                        running = false
                    }
                } label: {
                    Label(running ? "Running…" : "Run tests", systemImage: "play.fill")
                }
                .disabled(running)

                if !suite.results.isEmpty {
                    HStack {
                        Label("\(suite.passed) passed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Label("\(suite.failed) failed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(suite.failed == 0 ? Color.secondary : Color.red)
                    }
                    .font(.subheadline.bold())
                }
            }

            if !suite.results.isEmpty {
                Section("Results") {
                    ForEach(suite.results) { r in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(r.name, systemImage: r.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(r.passed ? .green : .red)
                                .font(.callout)
                            if !r.passed {
                                Text(r.detail).font(.caption).foregroundStyle(.secondary)
                                    .padding(.leading, 28)
                            }
                        }
                    }
                }
            }
        }
        .animation(.snappy, value: suite.results.count)
        .navigationTitle("XCTest Patterns")
    }
}

#Preview { NavigationStack { TestingDemoView() } }
