# SwiftUI Views & Composition

## Core Principles

- **Extract complex views into separate `View` structs** — not computed properties or `@ViewBuilder` methods. Separate structs allow SwiftUI to skip `body` when inputs don't change.
- **One type per file.** Flag files containing multiple type definitions.
- **Keep `body` simple and pure** — no side effects, no complex logic inline.
- **Button actions should be methods**, not inline closures mixing layout and logic.
- **Business logic belongs in services/models**, not views.

## Prefer Modifiers Over Conditional Views

Use modifiers to maintain view identity across state changes:

```swift
// GOOD — same view, different states
SomeView()
    .opacity(isVisible ? 1 : 0)

// AVOID — creates/destroys view identity
if isVisible {
    SomeView()
}
```

Use conditionals only for **fundamentally different views**:

```swift
if isLoggedIn {
    DashboardView()
} else {
    LoginView()
}
```

Avoid `if`-based conditional modifier extensions — they change return types and break view identity/animations.

## Extract Subviews, Not Computed Properties

```swift
// BAD — re-executes on every parent state change
@ViewBuilder
func complexSection() -> some View {
    ForEach(0..<100) { i in
        HStack { Image(systemName: "star"); Text("Item \(i)") }
    }
}

// GOOD — SwiftUI can skip body when inputs don't change
struct ComplexSection: View {
    var body: some View {
        ForEach(0..<100) { i in
            HStack { Image(systemName: "star"); Text("Item \(i)") }
        }
    }
}
```

`@ViewBuilder` functions are acceptable only for small, simple, static sections.

## Container View Pattern

Store built view values, not closures:

```swift
// BAD — closure prevents skip optimization
struct CardView<Content: View>: View {
    let content: () -> Content
    var body: some View { VStack { content() } }
}

// GOOD — synthesized init handles calling the builder
struct CardView<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { VStack { content } }
}
```

## ZStack vs overlay/background

- **`overlay`/`background`**: decorating a primary view (size anchored to parent)
- **`ZStack`**: composing multiple peer views that define layout together

## Compositing Group Before Clipping

Always add `.compositingGroup()` before `.clipShape()` on layered views to avoid antialiasing fringes:

```swift
Color.red
    .overlay(.white, in: .rect)
    .compositingGroup()
    .clipShape(RoundedRectangle(cornerRadius: 16))
```

## Reusable Styling

Use `ViewModifier` for repeated modifier combinations. Expose via `View` extension:

```swift
private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 12))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}
```

Use static member lookup for custom styles:

```swift
extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { .init() }
}
// Usage: .buttonStyle(.primary)
```

## TextField vs TextEditor

Prefer `TextField` with `axis: .vertical` over `TextEditor` (allows placeholder text). Use `lineLimit(5...)` for minimum height.

## Tab Views

Use enums for `TabView(selection:)`:

```swift
Tab("Home", systemImage: "house", value: .home)
```

## UIViewRepresentable

- `makeUIView(context:)` — called once
- `updateUIView(_:context:)` — called every SwiftUI redraw
- Struct itself recreated every redraw — avoid heavy init work
- Use `Coordinator` for delegates

## Skeleton Loading

```swift
VStack {
    Text(article?.title ?? String(repeating: "X", count: 20))
    Text("SwiftLee").unredacted()
}
.redacted(reason: article == nil ? .placeholder : [])
```

## Image Rendering

Use `ImageRenderer` over `UIGraphicsImageRenderer` for SwiftUI → image conversion.

## Previews

Use `#Preview` (not `PreviewProvider`). Use `@Previewable` for dynamic state (iOS 18+).
