import Foundation

// MARK: - Domain Use Case: FetchFeedUseCase
//
// Clean Architecture — Use Cases
// ───────────────────────────────
// A use case = ONE business operation. "Fetch next page of feed" is one.
// "Like a photo", "Report a photo", "Download for offline" would each be
// separate use cases. Use cases are where business RULES live — things
// like "page size is always 30", "premium users see 50 per page",
// "NSFW content is filtered before reaching the UI".
//
// Why not call the repository directly from the ViewModel?
//   1. Business rules have ONE home, not scattered across view models.
//   2. Testing: mock one use case instead of re-stubbing every edge case
//      of the repository every time.
//   3. Reusability: the same use case runs from a widget, a watchOS
//      extension, a SiriKit intent, or a CLI — all without a view model.
//   4. Presentation depends on use cases, not on repositories — keeping
//      the dependency graph flowing strictly inward.
nonisolated struct FetchFeedUseCase: Sendable {
    let repository: any FeedRepository
    let pageSize: Int

    init(repository: any FeedRepository, pageSize: Int = 30) {
        self.repository = repository
        self.pageSize = pageSize
    }

    func execute(page: Int) async throws -> [Photo] {
        try await repository.fetchPage(page, pageSize: pageSize)
    }
}
