import Foundation

// Two test doubles:
//  - Stub: returns canned data (the price table).
//  - Spy: records how it was called (calls array) so tests can assert interactions.
// Same object plays both roles here, like a typical hand-rolled mock.

final class MockPriceService: PriceService {
    var table: [String: Decimal]
    private(set) var calls: [String] = []   // spy: which SKUs were looked up
    var failSKU: String?                     // force an error path

    init(_ table: [String: Decimal]) { self.table = table }

    func price(for sku: String) async throws -> Decimal {
        calls.append(sku)
        if sku == failSKU { throw StoreError.unknownSKU }
        guard let p = table[sku] else { throw StoreError.unknownSKU }
        return p
    }
}
