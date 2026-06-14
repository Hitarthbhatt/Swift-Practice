import Foundation

// Observer: a subject notifies many subscribers when its state changes.

protocol PlayerObserver: AnyObject {
    func playerDidChange(_ state: String) -> String
}

final class Player {
    private var observers: [PlayerObserver] = []
    private(set) var state = "paused"

    func subscribe(_ observer: PlayerObserver) { observers.append(observer) }

    func play() -> [String] {
        state = "playing"
        return observers.map { $0.playerDidChange(state) }
    }
}

final class UIObserver: PlayerObserver {
    func playerDidChange(_ state: String) -> String { "UI → \(state)" }
}

final class LockscreenObserver: PlayerObserver {
    func playerDidChange(_ state: String) -> String { "Lockscreen → \(state)" }
}

final class AnalyticsObserver: PlayerObserver {
    func playerDidChange(_ state: String) -> String { "Analytics → \(state)" }
}
