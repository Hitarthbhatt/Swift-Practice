import SwiftUI

struct LRUCacheDemoView: View {
    @State private var vm = LRUCacheViewModel()

    private let keys = Array(0...9)
    private let values = ["A","B","C","D","E","F","G","H","I","J"]
    private let capacities = [2, 3, 4, 5, 6]

    var body: some View {
        List {
            // Cache visualisation
            Section {
                if vm.entries.isEmpty {
                    Text("Cache is empty").foregroundStyle(.secondary).font(.caption)
                } else {
                    ForEach(vm.entries) { entry in
                        HStack {
                            Text(entry.position == 0 ? "MRU" : entry.position == vm.entries.count - 1 ? "LRU" : "   ")
                                .font(.caption2.bold())
                                .foregroundStyle(entry.position == 0 ? Color.green : entry.position == vm.entries.count - 1 ? Color.red : Color.secondary)
                                .frame(width: 32, alignment: .leading)
                            Text("key \(entry.key)")
                                .font(.caption.monospaced().bold())
                            Text("→ \"\(entry.value)\"")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("#\(entry.position + 1)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Text(vm.lastResult)
                    .font(.caption.monospaced())
                    .foregroundStyle(.blue)
            } header: {
                HStack {
                    Text("Cache State (\(vm.entries.count)/\(vm.capacity))")
                    Spacer()
                    Text("Capacity")
                    Picker("", selection: $vm.capacity) {
                        ForEach(capacities, id: \.self) { Text("\($0)") }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            // Controls
            Section {
                HStack {
                    Text("Key")
                    Spacer()
                    Picker("Key", selection: $vm.selectedKey) {
                        ForEach(keys, id: \.self) { Text("\($0)") }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 80)
                }
                HStack {
                    Text("Value")
                    Spacer()
                    Picker("Value", selection: $vm.inputValue) {
                        ForEach(values, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 60, height: 80)
                }
                HStack(spacing: 12) {
                    Button("GET") { vm.get() }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                    Button("PUT") { vm.put() }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                    Button("Clear", role: .destructive) { vm.clear() }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                }
            } header: { Text("Operations") }

            // Stats
            Section {
                LabeledContent("Hits",      value: "\(vm.hits)")
                LabeledContent("Misses",    value: "\(vm.misses)")
                LabeledContent("Hit Rate",  value: vm.hitRate)
                LabeledContent("Evictions", value: "\(vm.evictions)")
                if let e = vm.lastEvicted {
                    LabeledContent("Last Evicted", value: "key \(e)")
                        .foregroundStyle(.red)
                }
            } header: { Text("Stats") }
        }
        .navigationTitle("LRU Cache")
    }
}

#Preview {
    NavigationStack { LRUCacheDemoView() }
}
