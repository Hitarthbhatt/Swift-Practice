import SwiftUI

// MARK: - Navigation
// Interview: "How do you handle navigation in a large iOS app?"
//
// UIKit: UINavigationController (push/pop), present/dismiss
// SwiftUI: NavigationStack (iOS 16+) with NavigationPath
//
// Key patterns:
// 1. NavigationStack + NavigationPath — programmatic, type-safe navigation
// 2. NavigationLink(value:) + .navigationDestination(for:) — data-driven
// 3. Coordinator Pattern — decouple navigation logic from views (see CoordinatorPattern/)
//
// Senior/Staff considerations:
// - Deep linking requires programmatic navigation (not just NavigationLink)
// - NavigationPath is type-erased → can push heterogeneous types
// - Tab-based + NavigationStack per tab is the standard iOS pattern
// - Avoid deeply nested NavigationStacks (only one per tab)

// MARK: - Route types for type-safe navigation
enum Topic1Route: Hashable {
    case detail(Item)
    case settings
    case nestedList(category: String)

    struct Item: Hashable, Identifiable {
        let id: Int
        let title: String
        let subtitle: String
    }
}

// MARK: - NavigationStack with programmatic path
struct NavigationStackDemoView: View {
    // NavigationPath is the key to programmatic navigation
    // It's type-erased, so you can push different Hashable types
    @State private var path = NavigationPath()

    private let items = (1...10).map {
        Topic1Route.Item(id: $0, title: "Item \($0)", subtitle: "Detail for item \($0)")
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Data-Driven Navigation") {
                    ForEach(items) { item in
                        // NavigationLink(value:) — pushes value onto path
                        NavigationLink(value: Topic1Route.detail(item)) {
                            Label(item.title, systemImage: "doc")
                        }
                    }
                }

                Section("Programmatic Navigation") {
                    Button("Push Settings") {
                        path.append(Topic1Route.settings)
                    }
                    Button("Push Nested List") {
                        path.append(Topic1Route.nestedList(category: "Demo"))
                    }
                    Button("Deep Push (3 screens)") {
                        // Programmatic deep navigation — useful for deep links
                        path.append(Topic1Route.nestedList(category: "Deep"))
                        path.append(Topic1Route.detail(items[0]))
                        path.append(Topic1Route.settings)
                    }
                }

                Section("Path Management") {
                    Text("Stack depth: \(path.count)")
                    if !path.isEmpty {
                        Button("Pop to Root") {
                            path = NavigationPath()
                        }
                        Button("Pop One") {
                            path.removeLast()
                        }
                    }
                }
            }
            .navigationTitle("Navigation")
            // Register destinations for each route type
            .navigationDestination(for: Topic1Route.self) { route in
                switch route {
                case .detail(let item):
                    DetailView(item: item)
                case .settings:
                    SettingsPlaceholderView()
                case .nestedList(let category):
                    NestedListView(category: category, path: $path, items: items)
                }
            }
        }
    }
}

// MARK: - Destination Views
struct DetailView: View {
    let item: Topic1Route.Item

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
            Text(item.title)
                .font(.title)
            Text(item.subtitle)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(item.title)
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        Text("Settings Screen")
            .navigationTitle("Settings")
    }
}

struct NestedListView: View {
    let category: String
    @Binding var path: NavigationPath
    let items: [Topic1Route.Item]

    var body: some View {
        List(items.prefix(3)) { item in
            NavigationLink(value: Topic1Route.detail(item)) {
                Text(item.title)
            }
        }
        .navigationTitle(category)
    }
}

#Preview {
    NavigationStackDemoView()
}
