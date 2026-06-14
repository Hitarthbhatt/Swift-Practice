import Foundation

// Adapter: wrap incompatible SDK APIs behind one protocol your app owns.

protocol Analytics {
    func track(_ event: String) -> String
}

// Pretend these are third-party SDKs whose APIs you cannot change.
private struct FirebaseSDK {
    func logEvent(name: String) -> String { "Firebase.logEvent(\(name))" }
}

private struct MixpanelSDK {
    func record(_ action: String) -> String { "Mixpanel.record(\(action))" }
}

struct FirebaseAdapter: Analytics {
    private let sdk = FirebaseSDK()
    func track(_ event: String) -> String { sdk.logEvent(name: event) }
}

struct MixpanelAdapter: Analytics {
    private let sdk = MixpanelSDK()
    func track(_ event: String) -> String { sdk.record(event) }
}

struct CompositeAnalytics: Analytics {
    let children: [Analytics]
    func track(_ event: String) -> String {
        children.map { $0.track(event) }.joined(separator: "\n")
    }
}
