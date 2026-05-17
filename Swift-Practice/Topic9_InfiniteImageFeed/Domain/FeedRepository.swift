import Foundation

// MARK: - Domain Protocol: FeedRepository
//
// Clean Architecture — Dependency Inversion
// ──────────────────────────────────────────
// The Domain DEFINES the contract; the Data layer IMPLEMENTS it.
// Presentation depends only on this protocol — never on the concrete
// implementation. To swap Picsum → Unsplash → a local JSON stub, you
// change exactly ONE line in the composition root. No ViewModel, no
// View, and no other Data-layer code needs to change.
//
// This inversion is the whole point of clean architecture:
//   High-level policy (Domain) does NOT depend on low-level detail (Data).
//   Instead, low-level detail depends on high-level abstractions.
//
// Sendable: repositories may be accessed from any actor / task, so the
// interface is Sendable and implementations must be safe to share.
protocol FeedRepository: Sendable {
    func fetchPage(_ page: Int, pageSize: Int) async throws -> [Photo]
}
