import SwiftUI

// MARK: - Coordinator-driven navigation view
// The coordinator owns the path; views just emit events via the coordinator.

struct CoordinatorDemoView: View {
    @StateObject private var coordinator = AppCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            CoordinatorHomeView(coordinator: coordinator)
                .navigationDestination(for: CoordinatorRoute.self) { route in
                    switch route {
                    case .home:
                        CoordinatorHomeView(coordinator: coordinator)
                    case .profile(let userId):
                        CoordinatorProfileView(userId: userId, coordinator: coordinator)
                    case .settings:
                        Text("Settings (push)")
                            .navigationTitle("Settings")
                    case .detail(let itemId):
                        CoordinatorDetailView(itemId: itemId, coordinator: coordinator)
                    }
                }
        }
        .sheet(item: $coordinator.presentedSheet) { route in
            NavigationStack {
                switch route {
                case .settings:
                    Text("Settings Sheet")
                        .navigationTitle("Settings")
                default:
                    Text("Unknown")
                }
            }
        }
    }
}

// Make CoordinatorRoute identifiable for sheet presentation
extension CoordinatorRoute: Identifiable {
    var id: Self { self }
}

// MARK: - Views that use Coordinator (no direct navigation knowledge)

struct CoordinatorHomeView: View {
    let coordinator: AppCoordinator

    var body: some View {
        List {
            Section("Coordinator Navigation") {
                Button("View Profile (push)") {
                    coordinator.handle(.showProfile(userId: "user_42"))
                }
                Button("View Detail #1 (push)") {
                    coordinator.handle(.showDetail(itemId: 1))
                }
                Button("Open Settings (sheet)") {
                    coordinator.handle(.showSettings)
                }
            }

            Section("Info") {
                Text("Views don't know about each other. They only talk to the Coordinator.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Coordinator Demo")
    }
}

struct CoordinatorProfileView: View {
    let userId: String
    let coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle")
                .font(.system(size: 60))
            Text("User: \(userId)")
                .font(.title2)
            Button("View Detail #2") {
                coordinator.handle(.showDetail(itemId: 2))
            }
            Button("Pop to Root") {
                coordinator.handle(.popToRoot)
            }
        }
        .navigationTitle("Profile")
    }
}

struct CoordinatorDetailView: View {
    let itemId: Int
    let coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
            Text("Detail Item #\(itemId)")
                .font(.title2)
            Button("Go Back") {
                coordinator.handle(.goBack)
            }
        }
        .navigationTitle("Detail \(itemId)")
    }
}

#Preview {
    CoordinatorDemoView()
}
