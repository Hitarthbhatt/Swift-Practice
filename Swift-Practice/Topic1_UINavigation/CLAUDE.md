# Topic 1 — UI Navigation

SwiftUI NavigationStack + UIKit interop + lifecycle + deep links + Coordinator pattern.

## Files
- `SwiftUIBasicsView.swift` — SwiftUI primitives (State, Binding, layout).
- `NavigationStackDemo.swift` — `NavigationStack` + `NavigationPath`, type-safe routes (`Topic1Route`).
- `DeepLinkHandler.swift` — URL parsing → route push.
- `LifecycleDemo.swift` — SwiftUI view lifecycle (`onAppear`, `task`, scene phase).
- `UIKitInteropView.swift` — `UIViewControllerRepresentable` bridge.
- `CoordinatorPattern/AppCoordinator.swift` — `@Observable` coordinator owns path.
- `CoordinatorPattern/CoordinatorView.swift` — root view consumes coordinator.

## Conventions
- iOS 16+ NavigationStack only. No `NavigationView`.
- Routes = `Hashable` enums.
