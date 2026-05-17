import SwiftUI
import Combine

// MARK: - Coordinator Pattern
// Interview: "What is the Coordinator pattern and why use it?"
//
// Problem: Views/VCs managing their own navigation creates tight coupling.
//   View A knows about View B, B knows about C, etc. Hard to reuse, test, refactor.
//
// Solution: Extract navigation logic into a Coordinator object.
//   Views only emit events ("user tapped item"), Coordinator decides where to go.
//
// Benefits:
// - Views are reusable (don't know about other views)
// - Navigation flow is centralized and testable
// - Easy to change flow without touching views
// - Deep links just tell the coordinator where to go
//
// In UIKit: Coordinator holds UINavigationController, pushes/presents VCs
// In SwiftUI: Coordinator is an ObservableObject managing NavigationPath
//
// Senior/Staff: Coordinator is essential for apps with complex flows
//   (onboarding, auth, tab-based with deep links)

// MARK: - Flow Events (what views emit)
enum CoordinatorEvent {
    case showHome
    case showProfile(userId: String)
    case showSettings
    case showDetail(itemId: Int)
    case goBack
    case popToRoot
}

// MARK: - Route (what gets pushed onto NavigationPath)
enum CoordinatorRoute: Hashable {
    case home
    case profile(userId: String)
    case settings
    case detail(itemId: Int)
}

// MARK: - Coordinator
@MainActor
final class AppCoordinator: ObservableObject {
    @Published var path = NavigationPath()
    @Published var presentedSheet: CoordinatorRoute?

    func handle(_ event: CoordinatorEvent) {
        switch event {
        case .showHome:
            popToRoot()
        case .showProfile(let userId):
            path.append(CoordinatorRoute.profile(userId: userId))
        case .showSettings:
            // Present as sheet instead of push
            presentedSheet = .settings
        case .showDetail(let itemId):
            path.append(CoordinatorRoute.detail(itemId: itemId))
        case .goBack:
            if !path.isEmpty { path.removeLast() }
        case .popToRoot:
            popToRoot()
        }
    }

    // Deep link support: reset path and navigate
    func handleDeepLink(_ deepLink: DeepLink) {
        popToRoot()

        switch deepLink {
        case .home:
            break
        case .detail(let id):
            if let itemId = Int(id) {
                path.append(CoordinatorRoute.detail(itemId: itemId))
            }
        default:
            break
        }
    }

    private func popToRoot() {
        path = NavigationPath()
    }
}
