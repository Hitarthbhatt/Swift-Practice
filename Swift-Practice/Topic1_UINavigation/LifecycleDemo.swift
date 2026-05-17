import SwiftUI
import UIKit

// MARK: - Lifecycle Management
// Interview: "Explain the iOS app lifecycle and view lifecycle"
//
// App Lifecycle (UIKit):
//   Not Running → Inactive → Active → Background → Suspended → Terminated
//   - AppDelegate: app-level events (launch, push tokens, background fetch)
//   - SceneDelegate: UI lifecycle per window (foreground/background transitions)
//
// App Lifecycle (SwiftUI):
//   @main App struct + Scene protocol
//   - .onChange(of: scenePhase) replaces SceneDelegate
//   - ScenePhase: .active, .inactive, .background
//
// View Lifecycle (SwiftUI):
//   - onAppear / onDisappear (like viewDidAppear / viewDidDisappear)
//   - .task { } — async work tied to view lifetime (auto-cancelled on disappear)
//   - .task(id:) — re-runs when id changes
//
// View Lifecycle (UIKit):
//   loadView → viewDidLoad → viewWillAppear → viewDidAppear
//   → viewWillDisappear → viewDidDisappear → deinit
//
// Senior/Staff: Know when to use AppDelegate adapter in SwiftUI apps
//   (push notifications, background fetch, third-party SDK init)

// MARK: - AppDelegate Adapter for SwiftUI
// Use @UIApplicationDelegateAdaptor when you need AppDelegate callbacks
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("📱 AppDelegate: didFinishLaunchingWithOptions")
        // Initialize SDKs, configure logging, etc.
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 AppDelegate: Push token = \(token)")
        // Broadcast so any interested view can display the token
        NotificationCenter.default.post(name: .apnsTokenReceived, object: nil, userInfo: ["token": token])
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("📱 AppDelegate: Failed to register for push: \(error)")
        NotificationCenter.default.post(name: .apnsTokenReceived, object: nil, userInfo: ["token": "❌ \(error.localizedDescription)"])
    }
}


// MARK: - Scene Phase Demo
struct LifecycleDemoView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var lifecycleLog: [String] = []
    @State private var taskResult: String = "Loading..."

    var body: some View {
        List {
            Section("Scene Phase (app lifecycle)") {
                Text("Current: **\(String(describing: scenePhase))**")
                Text("Move app to background and back to see changes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(".task { } — async work tied to view") {
                Text(taskResult)
            }

            Section("Lifecycle Log") {
                if lifecycleLog.isEmpty {
                    Text("Events will appear here")
                        .foregroundStyle(.secondary)
                }
                ForEach(lifecycleLog, id: \.self) { entry in
                    Text(entry)
                        .font(.caption.monospaced())
                }
            }
        }
        .navigationTitle("Lifecycle")
        // SwiftUI view lifecycle
        .onAppear {
            log("onAppear")
        }
        .onDisappear {
            log("onDisappear")
        }
        // Async task tied to view lifetime — cancelled when view disappears
        .task {
            log(".task started")
            do {
                try await Task.sleep(for: .seconds(1))
                taskResult = "Loaded after 1s ✅"
                log(".task completed")
            } catch {
                log(".task cancelled")
            }
        }
        // React to scene phase changes
        .onChange(of: scenePhase) { oldPhase, newPhase in
            log("scenePhase: \(oldPhase) → \(newPhase)")
        }
    }

    private func log(_ event: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        lifecycleLog.append("[\(timestamp)] \(event)")
    }
}

#Preview {
    NavigationStack {
        LifecycleDemoView()
    }
}
