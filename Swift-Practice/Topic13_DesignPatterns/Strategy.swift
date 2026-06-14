import Foundation

// Strategy: swap the algorithm at runtime behind a common protocol.

protocol DiscountStrategy {
    var name: String { get }
    func apply(to price: Decimal) -> Decimal
}

struct RegularPricing: DiscountStrategy {
    let name = "Regular"
    func apply(to price: Decimal) -> Decimal { price }
}

struct MemberPricing: DiscountStrategy {
    let name = "Member"
    func apply(to price: Decimal) -> Decimal { price * 0.8 }
}

struct ClearancePricing: DiscountStrategy {
    let name = "Clearance"
    func apply(to price: Decimal) -> Decimal { price * 0.5 }
}

struct Checkout {
    var strategy: DiscountStrategy
    func total(_ price: Decimal) -> Decimal { strategy.apply(to: price) }
}
