# Topic 13 — Design Patterns (iOS-flavored)

6 GoF patterns interviewers ask, each with one real iOS scenario. One interactive screen:
tap a pattern → see the scenario → **Run** → inline output.

## Files
- `Factory.swift` — `PaymentProcessor` + `PaymentFactory.make(kind)` (ApplePay/Card/PayPal). `Decimal.usd` helper.
- `Builder.swift` — fluent `RequestBuilder` → `URLRequest` (method/path/query/header/body).
- `Facade.swift` — `ImageService.load(url)` hides `Downloader` + `ImageDecoder` + `ImageCache`.
- `Adapter.swift` — `Analytics` protocol; `FirebaseAdapter`/`MixpanelAdapter` wrap clashing SDKs; `CompositeAnalytics` fans out.
- `Observer.swift` — `Player` subject notifies `PlayerObserver`s (UI/Lockscreen/Analytics).
- `Strategy.swift` — `DiscountStrategy` (Regular/Member/Clearance); `Checkout` delegates.
- `DesignPatternModels.swift` — `PatternDemo` + `DesignPatternLibrary.all()` wiring the 6 runs.
- `DesignPatternsView.swift` — interactive list (expand → Run → output).

## Cheat sheet
| Pattern | What | When | Real iOS | Gotcha |
|---|---|---|---|---|
| Factory | Centralize object creation; return a protocol | Many variants chosen at runtime | `UIViewController` factories, payment/provider selection | Don't let it become a god-switch; split into sub-factories |
| Builder | Step-by-step construct with a fluent chain | Many optional params; avoid telescoping init | `URLComponents`/`URLRequest`, `NSAttributedString` | Value-type builders copy each step; return `self` |
| Facade | Simple front over a complex subsystem | Hide messy coordination from callers | `URLSession` wrappers, an `ImageService` over cache+decode | Facade ≠ god object; keep subsystems usable directly |
| Adapter | Make an incompatible API fit your protocol | Bridge 3rd-party/legacy SDKs | Analytics/auth/payment SDKs behind one protocol | Adapter only translates — no business logic inside |
| Observer | Subject broadcasts to many subscribers | One-to-many state change | **Swift-native**: `@Observable`, Combine `@Published`, `NotificationCenter`, KVO | Hand-rolled observers → retain cycles; use `weak`/`AnyObject` |
| Strategy | Swap algorithm at runtime behind a protocol | Interchangeable behaviors | sort/pricing/retry/image-loading strategies | Strategy = behavior injection; same input, different policy |

## Talking points
- **Observer in Swift is mostly built-in** — you rarely hand-roll it. Reach for `@Observable` (UI), Combine (streams), `NotificationCenter` (app-wide events), KVO (ObjC interop). The hand-rolled version here shows the raw mechanics.
- **Factory vs Builder:** Factory picks *which* type; Builder configures *one* complex type step by step.
- **Facade vs Adapter:** Facade *simplifies* a subsystem you own; Adapter *translates* an API you don't.
- **Strategy vs Factory:** both use a protocol — Strategy swaps *behavior*, Factory swaps *creation*.
- Demo note: `Analytics.track` / `PlayerObserver.playerDidChange` return `String` here only to show output; real ones return `Void`.
