import Foundation

struct PatternDemo: Identifiable {
    let id = UUID()
    let name: String
    let intent: String
    let scenario: String
    let run: () async -> [String]
}

enum DesignPatternLibrary {
    static func all() -> [PatternDemo] {
        [factory, builder, facade, adapter, observer, strategy]
    }

    private static var factory: PatternDemo {
        PatternDemo(
            name: "Factory",
            intent: "Ask for a kind; the factory builds the right type.",
            scenario: "Checkout picks a payment processor at runtime."
        ) {
            PaymentKind.allCases.map { PaymentFactory.make($0).pay(9.99) }
        }
    }

    private static var builder: PatternDemo {
        PatternDemo(
            name: "Builder",
            intent: "Assemble a complex object step by step, fluently.",
            scenario: "Build a search URLRequest without a giant initializer."
        ) {
            let request = RequestBuilder(base: "https://api.shop.com")
                .method("GET")
                .path("/search")
                .query("q", "shoes")
                .query("page", "2")
                .header("Accept", "application/json")
                .header("Authorization", "Bearer •••")
                .build()
            return [
                "\(request.httpMethod!) \(request.url!.absoluteString)",
                "\(request.allHTTPHeaderFields?.count ?? 0) headers attached"
            ]
        }
    }

    private static var facade: PatternDemo {
        PatternDemo(
            name: "Facade",
            intent: "One call hides a messy multi-step subsystem.",
            scenario: "load(url) hides download + decode + cache."
        ) {
            let service = ImageService()
            let url = URL(string: "https://cdn.shop.com/a.jpg")!
            let first = await service.load(url)
            let second = await service.load(url)
            return ["1st call → \(first)", "2nd call → \(second)"]
        }
    }

    private static var adapter: PatternDemo {
        PatternDemo(
            name: "Adapter",
            intent: "Wrap incompatible SDKs behind one protocol you own.",
            scenario: "Send one event to Firebase + Mixpanel together."
        ) {
            let analytics = CompositeAnalytics(children: [FirebaseAdapter(), MixpanelAdapter()])
            return analytics.track("checkout").components(separatedBy: "\n")
        }
    }

    private static var observer: PatternDemo {
        PatternDemo(
            name: "Observer",
            intent: "A subject notifies many subscribers on change.",
            scenario: "Player tells UI, Lockscreen and Analytics it started."
        ) {
            let player = Player()
            player.subscribe(UIObserver())
            player.subscribe(LockscreenObserver())
            player.subscribe(AnalyticsObserver())
            var lines = player.play()
            lines.insert("\(lines.count) subscribers notified:", at: 0)
            return lines
        }
    }

    private static var strategy: PatternDemo {
        PatternDemo(
            name: "Strategy",
            intent: "Swap the algorithm at runtime behind a protocol.",
            scenario: "Same $100 cart, different discount strategy."
        ) {
            let price: Decimal = 100
            let strategies: [DiscountStrategy] = [RegularPricing(), MemberPricing(), ClearancePricing()]
            return strategies.map { "\($0.name): \(Checkout(strategy: $0).total(price).usd)" }
        }
    }
}
