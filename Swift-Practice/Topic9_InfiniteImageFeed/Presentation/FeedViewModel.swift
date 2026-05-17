import Foundation

// MARK: - Presentation Layer: FeedViewModel
//
// Clean Architecture — Presentation Layer
// ────────────────────────────────────────
// Owns UI state. Knows about Use Cases, but NOT about repositories,
// DTOs, URLSession, or JSON. When Presentation depends only on the
// Domain, the whole UI can be unit-tested with a stub use case —
// no URL mocking, no network stubbing, no JSON fixtures.
//
// @Observable: Swift's modern observation framework. Properties marked
// on an @Observable class are tracked automatically; any SwiftUI view
// or UIKit observer (via `withObservationTracking`) re-renders when
// they change.
@Observable @MainActor
final class FeedViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var photos: [Photo] = []
    private(set) var state: LoadState = .idle

    private var nextPage = 1
    private var isLoadingPage = false
    private var reachedEnd = false

    private let useCase: FetchFeedUseCase

    init(useCase: FetchFeedUseCase) {
        self.useCase = useCase
    }

    // Called from:
    //   • viewDidLoad — to fetch the first page
    //   • prefetchItemsAt — when the user scrolls near the end of the list
    //
    // The `isLoadingPage` guard makes this idempotent — calling it 20
    // times in the same run loop tick still only triggers ONE network
    // request. The `reachedEnd` flag short-circuits once the API starts
    // returning empty pages.
    func loadNextPageIfNeeded() async {
        guard !isLoadingPage, !reachedEnd else { return }
        isLoadingPage = true
        state = .loading
        defer { isLoadingPage = false }

        do {
            let newPhotos = try await useCase.execute(page: nextPage)
            if newPhotos.isEmpty {
                reachedEnd = true
            } else {
                photos.append(contentsOf: newPhotos)
                nextPage += 1
            }
            state = .loaded
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
