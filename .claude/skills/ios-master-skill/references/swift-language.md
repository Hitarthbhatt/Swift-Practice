# Swift Language Best Practices

## Modern Idioms

- Use `if let value {` shorthand over `if let value = value {`.
- Omit `return` for single-expression functions. `if`/`switch` work as expressions.
- Prefer `Double` over `CGFloat` (Swift bridges freely, except optionals/inout).
- Prefer `Date.now` over `Date()`.
- Prefer `count(where:)` over `filter().count`.
- Prefer static member lookup: `.circle` over `Circle()`, `.borderedProminent` over `BorderedProminentButtonStyle()`.
- Use `if`/`switch` expressions for returns and assignments:

```swift
var tileColor: Color {
    if isCorrect { .green } else { .red }
}
```

## String Handling

- Prefer Swift-native: `replacing("a", with: "b")` over `replacingOccurrences(of:with:)`.
- User-input filtering: always `localizedStandardContains()` (not `contains()` or `localizedCaseInsensitiveContains()`).
- People names: use `PersonNameComponents` with modern formatting.
- Avoid manual date format strings for display. Use `y` not `yyyy` for years if manual formatting is needed.
- Convert strings to dates: `Date(myString, strategy: .iso8601)`.

## Number Formatting

Never use C-style `String(format:)`:

```swift
// GOOD
Text(value, format: .number.precision(.fractionLength(2)))
Text(100, format: .currency(code: "USD"))

// BAD
String(format: "%.2f", value)
```

## URL Handling

- Prefer `URL.documentsDirectory` over FileManager directory lookups.
- Use `appending(path:)` to append strings to URLs.

## Error Handling

- Avoid force unwraps (`!`) and force `try` unless truly unrecoverable (use `fatalError()` with description).
- Prefer `if let`, `guard let`, nil-coalescing, `try?`/`do-catch`.
- Flag silently swallowed errors (e.g., `print(error.localizedDescription)` instead of showing alert).

## Collections

- If a sort closure is repeated, make the type conform to `Comparable`.
- When `import SwiftUI` is present, no need for `import UIKit`/`import AppKit`.

## Concurrency (Quick Rules)

- Always prefer `async`/`await` over closure-based variants.
- Never use GCD (`DispatchQueue.main.async`, `DispatchQueue.global()`). Use Swift concurrency.
- Never use `Task.sleep(nanoseconds:)` — use `Task.sleep(for:)`.
- Flag mutable shared state not protected by actor or `@MainActor`.
- `Task.detached()` is often wrong. Check carefully.
- Check default actor isolation before flagging `MainActor.run()` as needed.
