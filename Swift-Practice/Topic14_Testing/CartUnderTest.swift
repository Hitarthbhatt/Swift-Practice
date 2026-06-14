import Foundation

// System under test: a cart whose prices come from an injected service.
// Injection is what makes it testable — swap the real service for a mock.

enum StoreError: Error, Equatable { case unknownSKU }

protocol PriceService: Sendable {
    func price(for sku: String) async throws -> Decimal
}

@Observable
final class Cart {
    private let prices: PriceService
    private(set) var items: [String: Int] = [:]
    private(set) var total: Decimal = 0

    init(prices: PriceService) { self.prices = prices }

    func add(_ sku: String, qty: Int = 1) async throws {
        items[sku, default: 0] += qty
        try await recompute()
    }

    func remove(_ sku: String) async throws {
        items[sku] = nil
        try await recompute()
    }

    private func recompute() async throws {
        var t: Decimal = 0
        for (sku, qty) in items {
            t += try await prices.price(for: sku) * Decimal(qty)
        }
        total = t
    }
}
