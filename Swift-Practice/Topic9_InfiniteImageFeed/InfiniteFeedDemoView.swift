import SwiftUI
import UIKit

// MARK: - Composition Root
//
// Clean Architecture — Wiring everything together
// ─────────────────────────────────────────────────
// This is the ONE place in the entire project that knows about every
// concrete class in Topic 9. It constructs the dependency graph top-down:
//
//     PicsumFeedRepository  (Data)          ← concrete implementation
//             ↓ injected into
//     FetchFeedUseCase      (Domain)        ← business rule: page size
//             ↓ injected into
//     FeedViewModel         (Presentation)  ← UI state
//             ↓ injected into
//     FeedViewController    (Presentation)  ← UIKit rendering
//
// To swap the data source for a fake (unit test), a local JSON stub
// (SwiftUI previews), or a different provider (Unsplash), you change
// the FIRST line of `makeUIViewController` — and nothing else.
// No grep-across-the-project refactor. That's the payoff of the
// dependency-inversion rule.
struct InfiniteFeedDemoView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> FeedViewController {
        let repository: any FeedRepository = PicsumFeedRepository()
        let useCase    = FetchFeedUseCase(repository: repository)
        let viewModel  = FeedViewModel(useCase: useCase)
        return FeedViewController(viewModel: viewModel)
    }

    func updateUIViewController(_ vc: FeedViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        InfiniteFeedDemoView()
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationTitle("Infinite Feed")
            .navigationBarTitleDisplayMode(.inline)
    }
}
