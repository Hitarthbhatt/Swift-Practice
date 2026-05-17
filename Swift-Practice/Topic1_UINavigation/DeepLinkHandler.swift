import SwiftUI
import Combine

// MARK: - Deep Link Handling
// Interview: "How do you handle deep links in iOS?"
// Key points:
// - Universal Links (HTTPS) vs Custom URL Schemes (myapp://)
// - Parse URL into app-specific routes
// - Navigate to correct screen from any state
// - Handle deferred deep links (app not installed)

enum DeepLink: Equatable {
    case home
    case swiftUIBasics
    case uikitInterop
    case lifecycle
    case navigationDemo
    case coordinator
    case detail(id: String)

    // Parse URL like: swiftpractice://topic1/swiftui-basics
    // or Universal Link: https://example.com/topic1/detail/42
    init?(url: URL) {
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard let first = pathComponents.first else {
            self = .home
            return
        }

        switch first {
        case "swiftui-basics":
            self = .swiftUIBasics
        case "uikit-interop":
            self = .uikitInterop
        case "lifecycle":
            self = .lifecycle
        case "navigation":
            self = .navigationDemo
        case "coordinator":
            self = .coordinator
        case "detail":
            if let id = pathComponents.dropFirst().first {
                self = .detail(id: id)
            } else {
                return nil
            }
        default:
            return nil
        }
    }
}

// Observable deep link manager that any view can subscribe to
@MainActor
final class DeepLinkHandler: ObservableObject {
    @Published var pendingDeepLink: DeepLink?

    func handle(url: URL) {
        guard let deepLink = DeepLink(url: url) else {
            print("⚠️ Unrecognized deep link: \(url)")
            return
        }
        print("✅ Deep link parsed: \(deepLink)")
        pendingDeepLink = deepLink
    }

    func consume() {
        pendingDeepLink = nil
    }
}
