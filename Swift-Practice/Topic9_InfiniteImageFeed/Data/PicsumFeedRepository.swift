import Foundation

// MARK: - Data Layer: PicsumFeedRepository
//
// Clean Architecture — Data Layer
// ────────────────────────────────
// Implements the Domain's FeedRepository contract using the Picsum
// Photos public API. Responsibilities that live ONLY here — never
// leaking into the Domain or Presentation layers:
//
//   • API URL format              (https://picsum.photos/v2/list?...)
//   • JSON decoding + DTO mapping
//   • HTTP status-code handling
//   • Retry policy + backoff      (reuses Topic 8's ExponentialBackoff)
//
// If we switched to Unsplash tomorrow, ONLY this file would change.
// That's the payoff of the layered design.
nonisolated struct PicsumFeedRepository: FeedRepository {
    private let baseURL = URL(string: "https://picsum.photos/v2/list")!
    private let session: URLSession
    private let policy: any RetryPolicy

    init(
        session: URLSession = .shared,
        policy: any RetryPolicy = ExponentialBackoff(
            maxAttempts: 3, base: 0.5, cap: 5, jitter: true
        )
    ) {
        self.session = session
        self.policy = policy
    }

    func fetchPage(_ page: Int, pageSize: Int) async throws -> [Photo] {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "page",  value: "\(page)"),
            .init(name: "limit", value: "\(pageSize)")
        ]
        let url = comps.url!

        // Inline retry loop that reuses Topic 8's RetryPolicy abstraction.
        //
        // Why not call `withRetry(...)` from Topic 8 directly?
        //   Its `onEvent` closure is `@MainActor`-isolated (it was designed
        //   to push log lines into a SwiftUI view). Calling it from the Data
        //   layer would couple the repository to the main actor, which is
        //   wrong — a repository should be callable from any actor.
        //
        // Reusing just the `RetryPolicy` protocol + `ExponentialBackoff`
        // struct gives us the same exponential-backoff-with-jitter math
        // without the MainActor coupling.
        var lastError: Error?
        for attempt in 0..<policy.maxAttempts {
            try Task.checkCancellation()
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                let dtos = try JSONDecoder().decode([PicsumPhotoDTO].self, from: data)
                return dtos.map { $0.toDomain() }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if attempt < policy.maxAttempts - 1 {
                    try await Task.sleep(for: policy.delay(forAttempt: attempt))
                }
            }
        }
        throw lastError ?? URLError(.unknown)
    }
}

// MARK: - DTO (Data Transfer Object)
//
// DTOs are Data-layer-only. They mirror the exact shape of the API's
// JSON response. The Domain never imports this type — mapping happens
// at the layer boundary via `toDomain()`.
//
// Why separate DTO from Domain?
//   • API shape changes (renames, added fields) don't ripple into the UI.
//   • The Domain's `Photo` can have invariants the API doesn't enforce
//     (e.g. non-optional thumbnail URL).
//   • Easier to mock — just encode a JSON fixture, no type gymnastics.
private struct PicsumPhotoDTO: Decodable {
    let id: String
    let author: String

    func toDomain() -> Photo {
        // Picsum supports on-the-fly resize: /id/{id}/{width}/{height}.
        // 400x400 is cheap to transfer and plenty sharp for a 3-column
        // grid on a @3x retina device (≈130pt cells → 390 physical px).
        let thumb = URL(string: "https://picsum.photos/id/\(id)/400/400")!
        return Photo(id: id, author: author, thumbnailURL: thumb)
    }
}
