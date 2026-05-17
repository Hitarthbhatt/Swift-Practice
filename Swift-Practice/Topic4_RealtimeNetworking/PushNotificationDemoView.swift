import SwiftUI
import UserNotifications
import UIKit

extension Notification.Name {
    static let apnsTokenReceived = Notification.Name("apnsTokenReceived")
}

// MARK: - Interview: Push Notifications
//
// Two types:
//   • Local  — scheduled on-device, no server needed (this demo)
//   • Remote — APNs (Apple Push Notification service) delivers from backend
//
// Remote push flow:
//   App → registerForRemoteNotifications()
//   → APNs issues device token → AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken
//   → App uploads token to backend
//   → Backend → APNs (HTTP/2 + JWT or certificate) → APNs → device
//
// Payload types:
//   • Alert         — title + body, shown in notification UI
//   • Silent        — content-available: 1, no UI, wakes app in background (30s budget)
//   • Background    — same as silent but declared in background modes
//   • Rich          — attachment (image/video) via UNNotificationServiceExtension
//
// Foreground handling: UNUserNotificationCenterDelegate.willPresent
//   — decide whether to show banner even when app is active
// Background/tap handling: didReceive(_:withContentHandler:)
//
// Authorization options (each shown separately at OS level):
//   .alert, .badge, .sound, .criticalAlert (entitlement), .provisional (no prompt)

// MARK: - Notification Categories & Actions
// Define once at app launch; used to render action buttons on notification banners.
private enum PushCategory {
    static let reminder = "REMINDER"

    static func register() {
        let snooze = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Snooze 5 min",
            options: []
        )
        let dismiss = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: reminder,
            actions: [snooze, dismiss],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

// MARK: - ViewModel

@Observable
final class PushNotificationViewModel: NSObject {
    // Permission
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var statusLabel: String = "Unknown"

    // APNs
    var apnsToken: String = "Not registered"

    // Local notifications
    var pendingCount: Int = 0
    var deliveredCount: Int = 0
    var lastTappedAction: String = ""

    override init() {
        super.init()
        // Interview: set delegate before app finishes launching ideally;
        // here we set it lazily when the view appears — fine for demo
        UNUserNotificationCenter.current().delegate = self
        PushCategory.register()
        observeAPNSToken()
    }

    // MARK: - Permission

    func requestPermission() async {
        do {
            // Interview: request minimal options first; add .badge/.sound per UX need
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            if granted {
                // Interview: must call from main thread
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } catch {
            statusLabel = "❌ \(error.localizedDescription)"
        }
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        statusLabel = settings.authorizationStatus.label
        await refreshCounts()
    }

    // MARK: - Schedule Local Notifications

    /// Simple alert — fires after `delay` seconds
    func scheduleAlert(delay: TimeInterval = 5) {
        let content = UNMutableNotificationContent()
        content.title = "Local Alert"
        content.body = "Fired after \(Int(delay))s — tap to see action handling"
        content.sound = .default
        content.badge = NSNumber(value: (deliveredCount + pendingCount + 1))
        // Interview: userInfo carries arbitrary data to the app on tap
        content.userInfo = ["source": "alert_demo", "delay": delay]
        content.categoryIdentifier = PushCategory.reminder  // attaches action buttons

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { [weak self] _ in
            Task { await self?.refreshCounts() }
        }
    }

    /// Silent / data notification (local equivalent — no alert, just userInfo)
    /// Interview: real silent push has content-available:1 in APNs payload,
    ///            no alert/sound/badge, arrives even when app is suspended.
    func scheduleSilent() {
        let content = UNMutableNotificationContent()
        content.userInfo = ["type": "silent", "payload": "background_sync_trigger"]
        // No title/body/sound — silent delivery
        // Interview: on a real device this wakes the app for ~30 s of background work

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "silent_\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { [weak self] _ in
            Task { await self?.refreshCounts() }
        }
        lastTappedAction = "Silent notification queued (no banner shown)"
    }

    func clearAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
        Task { await refreshCounts() }
    }

    // MARK: - Private

    private func refreshCounts() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        pendingCount = pending.count
        deliveredCount = delivered.count
    }

    private func observeAPNSToken() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToken(_:)),
            name: .apnsTokenReceived,
            object: nil
        )
    }

    @objc private func handleToken(_ notification: Foundation.Notification) {
        apnsToken = notification.userInfo?["token"] as? String ?? "unknown"
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationViewModel: UNUserNotificationCenterDelegate {
    // Interview: called when notification arrives while app is in foreground
    // Return .banner + .sound to still show it; return [] to suppress silently
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
        Task { await refreshCounts() }
    }

    // Interview: called when user taps notification or an action button
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        switch actionID {
        case UNNotificationDefaultActionIdentifier:
            lastTappedAction = "Tapped banner — userInfo: \(userInfo)"
        case "SNOOZE":
            lastTappedAction = "Snoozed — reschedule in 5 min"
            scheduleAlert(delay: 5) // demo: re-schedule immediately at 5 s
        case "DISMISS":
            lastTappedAction = "Dismissed"
        default:
            lastTappedAction = "Action: \(actionID)"
        }

        Task { await refreshCounts() }
        completionHandler()
    }
}

// MARK: - UNAuthorizationStatus helper

private extension UNAuthorizationStatus {
    var label: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .denied:        return "Denied — change in Settings"
        case .authorized:    return "Authorized"
        case .provisional:   return "Provisional (quiet)"
        case .ephemeral:     return "Ephemeral"
        @unknown default:    return "Unknown"
        }
    }
}

// MARK: - View

struct PushNotificationDemoView: View {
    @State private var vm = PushNotificationViewModel()

    var body: some View {
        List {
            // MARK: Permission
            Section {
                LabeledContent("Status", value: vm.statusLabel)
                    .foregroundStyle(vm.authorizationStatus == .authorized ? Color.primary : Color.orange)

                Button("Request Permission") {
                    Task { await vm.requestPermission() }
                }
                .disabled(vm.authorizationStatus == .authorized)

                Button("Refresh Status") {
                    Task { await vm.refreshStatus() }
                }
                .foregroundStyle(.secondary)
            } header: { Text("Authorization") }

            // MARK: APNs Token
            Section {
                // Interview: token changes after app re-install or OS update;
                // backend must always accept token updates.
                Text(vm.apnsToken)
                    .font(.caption.monospaced())
                    .foregroundStyle(vm.apnsToken.hasPrefix("❌") ? .red : .secondary)
                    .lineLimit(4)
                    .textSelection(.enabled)

                Button("Register for Remote Push") {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                .disabled(vm.authorizationStatus != .authorized)
            } header: { Text("APNs Token (device only)") }
            footer: { Text("Token is issued by APNs. On simulator this will fail — expected.") }

            // MARK: Local Notifications
            Section {
                LabeledContent("Pending", value: "\(vm.pendingCount)")
                LabeledContent("Delivered", value: "\(vm.deliveredCount)")
            } header: { Text("Notification Queue") }

            Section {
                Button("Schedule Alert (5 s)") {
                    vm.scheduleAlert(delay: 5)
                }
                .disabled(vm.authorizationStatus != .authorized)

                Button("Schedule Silent (1 s)") {
                    vm.scheduleSilent()
                }
                .disabled(vm.authorizationStatus != .authorized)

                Button("Clear All", role: .destructive) {
                    vm.clearAll()
                }
            } header: { Text("Schedule Local Notifications") }
            footer: {
                Text("Alert notification includes Snooze / Dismiss action buttons (long-press banner to see them).")
            }

            // MARK: Last Action
            if !vm.lastTappedAction.isEmpty {
                Section {
                    Text(vm.lastTappedAction)
                        .font(.caption.monospaced())
                } header: { Text("Last Tap / Action") }
            }
        }
        .navigationTitle("Push Notifications")
        .task { await vm.refreshStatus() }
    }
}

#Preview {
    NavigationStack { PushNotificationDemoView() }
}
