import SwiftUI

@main
struct Swift_PracticeApp: App {
    // Connect UIKit AppDelegate to SwiftUI lifecycle
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var deepLinkHandler = DeepLinkHandler()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deepLinkHandler)
                // Handle incoming URLs (custom scheme or universal links)
                .onOpenURL { url in
                    deepLinkHandler.handle(url: url)
                }
        }
    }
}
