import SwiftUI

// MARK: - SwiftUI (Declarative UI)
// Interview: "Compare declarative vs imperative UI. When would you choose SwiftUI over UIKit?"
//
// Declarative (SwiftUI): Describe WHAT the UI should look like for a given state.
//   The framework figures out HOW to update. Re-renders on state change automatically.
//
// Imperative (UIKit): You manually tell the system each step to update the UI.
//   More control, but more boilerplate and potential for inconsistent state.
//
// SwiftUI Pros: Less code, built-in state management, previews, cross-platform
// SwiftUI Cons: Less mature, some UIKit features missing, harder to debug layout
//
// Senior/Staff: Know BOTH. Use SwiftUI for new screens, UIKit for complex/custom needs.

// MARK: - Property Wrappers for State (key interview topic)
// @State          — owned by this view, value type, private
// @Binding        — reference to parent's @State
// @StateObject    — owned by this view, reference type (ObservableObject)
// @ObservedObject — NOT owned, passed in, can be recreated
// @EnvironmentObject — injected via .environmentObject(), shared across tree

struct SwiftUIBasicsView: View {
    // @State: source of truth for simple value types
    @State private var counter = 0
    @State private var items = ["SwiftUI", "UIKit", "Combine"]
    @State private var showSheet = false

    var body: some View {
        List {
            Section("State Management") {
                Text("Counter: \(counter)")
                Button("Increment") { counter += 1 }

                // Passing a binding to child — child can modify parent's state
                CounterControl(counter: $counter)
            }

            Section("Dynamic List") {
                ForEach(items, id: \.self) { item in
                    Text(item)
                }
                .onDelete { offsets in
                    items.remove(atOffsets: offsets)
                }
            }

            Section("Presentation") {
                Button("Show Sheet") { showSheet = true }
            }
        }
        .listStyle(.plain)
        .navigationTitle("SwiftUI Basics")
        .sheet(isPresented: $showSheet) {
            SheetContent()
        }
    }
}

// MARK: - @Binding demo: child modifies parent state
struct CounterControl: View {
    @Binding var counter: Int

    var body: some View {
        HStack {
            Button("−") { counter = max(0, counter - 1) }
                .buttonStyle(BorderlessButtonStyle())
            Spacer()
            Text("\(counter)")
                .monospacedDigit()
            Spacer()
            Button("+") { counter += 1 }
                .buttonStyle(BorderlessButtonStyle())
        }
    }
}

// MARK: - @Environment demo: accessing system values
struct SheetContent: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("This is a presented sheet")
                .navigationTitle("Sheet")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        SwiftUIBasicsView()
    }
}
