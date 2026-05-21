import UIKit

// MARK: - Background URLSession event routing
//
// When the app is suspended/killed and a background download finishes, the OS
// relaunches the app and calls this. We stash the completion handler on the
// matching manager and fire it from urlSessionDidFinishEvents — that tells the
// system the UI is updated and it's safe to snapshot the app.

extension AppDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        switch identifier {
        case VideoDownloadManager.backgroundIdentifier:
            VideoDownloadManager.shared.backgroundCompletion = completionHandler
        case HLSDownloadManager.backgroundIdentifier:
            HLSDownloadManager.shared.backgroundCompletion = completionHandler
        default:
            completionHandler()
        }
    }
}
