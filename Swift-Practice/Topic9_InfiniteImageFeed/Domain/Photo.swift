import Foundation

// MARK: - Domain Entity: Photo
//
// Clean Architecture — Domain Layer
// ──────────────────────────────────
// Rules for Domain entities:
//   • Pure value type. No UIKit, no URLSession, no JSON.
//   • Framework-independent — could be copy-pasted into a server-side
//     Swift project, a Linux CLI, or a watchOS extension, and still compile.
//   • Represents WHAT the business cares about, not HOW it was fetched.
//
// The Picsum API returns ~10 fields per photo. The Domain exposes only
// the 3 the UI actually uses. Keeping this surface narrow means API
// drift rarely ripples past the Data layer.
//
// `nonisolated` opts this type out of the project's
// `-default-isolation=MainActor` setting. Without it, Photo (and its
// Hashable conformance) would be main-actor-isolated, which prevents
// it from satisfying UICollectionViewDiffableDataSource's Sendable
// requirement on its ItemIdentifierType.
nonisolated struct Photo: Identifiable, Hashable, Sendable {
    let id: String
    let author: String
    let thumbnailURL: URL

    // ID-only equality: two photos with the same id are "the same photo"
    // even if metadata differs. This matters for the diffable data source —
    // we don't want to re-render a cell just because its `author` string
    // changed capitalization on the server.
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Photo, rhs: Photo) -> Bool { lhs.id == rhs.id }
}
