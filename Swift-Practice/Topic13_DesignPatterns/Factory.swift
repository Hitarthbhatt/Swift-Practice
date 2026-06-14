import Foundation

// Factory: ask for a kind; the factory returns the right concrete type.

enum PaymentKind: String, CaseIterable {
    case applePay = "Apple Pay"
    case card = "Card"
    case payPal = "PayPal"
}

protocol PaymentProcessor {
    func pay(_ amount: Decimal) -> String
}

private struct ApplePayProcessor: PaymentProcessor {
    func pay(_ amount: Decimal) -> String { "Charged \(amount.usd) via Apple Pay" }
}

private struct CardProcessor: PaymentProcessor {
    func pay(_ amount: Decimal) -> String { "Charged \(amount.usd) via Card" }
}

private struct PayPalProcessor: PaymentProcessor {
    func pay(_ amount: Decimal) -> String { "Charged \(amount.usd) via PayPal" }
}

enum PaymentFactory {
    static func make(_ kind: PaymentKind) -> PaymentProcessor {
        switch kind {
        case .applePay: return ApplePayProcessor()
        case .card: return CardProcessor()
        case .payPal: return PayPalProcessor()
        }
    }
}

extension Decimal {
    var usd: String { "$" + NSDecimalNumber(decimal: self).stringValue }
}
