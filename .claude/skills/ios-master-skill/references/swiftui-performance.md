# SwiftUI Performance

## Key Optimization Rules

### 1. Avoid Redundant State Updates

```swift
// BAD — triggers update even if unchanged
.onReceive(publisher) { value in
    self.currentValue = value
}

// GOOD — only update when different
.onReceive(publisher) { value in
    if self.currentValue != value {
        self.currentValue = value
    }
}
```

### 2. Optimize Hot Paths

Scroll handlers, animations, gesture handlers fire constantly. Gate state updates by thresholds:

```swift
.onPreferenceChange(ScrollOffsetKey.self) { offset in
    let shouldShow = offset.y <= -32
    if shouldShow != shouldShowTitle {
        shouldShowTitle = shouldShow
    }
}
```

### 3. Pass Only Needed Values

Avoid passing large "config" or "context" objects. Pass specific values:

```swift
// GOOD
ItemRow(name: item.name, color: theme.primaryColor)

// BAD — broad dependency
ItemRow(item: item, model: appModel)
```

### 4. Use Ternaries Over if/else Branching

Ternary preserves structural identity and avoids `_ConditionalContent`:

```swift
Text("Hello")
    .foregroundStyle(isError ? .red : .primary)
```

### 5. Avoid AnyView

Use `@ViewBuilder`, `Group`, or generics instead. `AnyView` defeats the diff engine.

### 6. View Initializers Must Be Lightweight

Move non-trivial work to `.task()` modifier. Never do expensive computation in `init`.

### 7. Move Logic Out of body

`body` is called frequently. Sorting, filtering, formatting should be precomputed:

```swift
// BAD
List(items.sorted { $0.name < $1.name }) { ... }

// GOOD
@State private var sortedItems: [Item] = []
List(sortedItems) { ... }
    .onChange(of: items) { _, newItems in
        sortedItems = newItems.sorted { $0.name < $1.name }
    }
```

### 8. Use Lazy Containers for Large Collections

```swift
ScrollView {
    LazyVStack {
        ForEach(items) { item in ExpensiveRow(item: item) }
    }
}
```

### 9. Prefer .task() Over onAppear for Async Work

`.task()` cancels automatically on disappear.

### 10. ForEach Identity Rules

- Use **stable** identity (Identifiable or explicit `id:`)
- Never use `.indices` for dynamic content
- Ensure **constant** number of views per ForEach element
- Avoid inline filtering in ForEach (prefilter and cache)
- Never use `AnyView` in list rows

### 11. POD Views for Fast Diffing

Plain Old Data views (only simple value types, no property wrappers) use `memcmp` for fastest comparison:

```swift
struct FastView: View {
    let title: String
    let count: Int
    var body: some View { Text("\(title): \(count)") }
}
```

Wrap expensive non-POD views in POD parent views for fast outer comparison.

### 12. @Observable Dependency Granularity

Consider per-item `@Observable` state holders to narrow update scope. When all rows share one array, toggling one item re-evaluates all rows.

### 13. Avoid Storing Frequently-Changing Values in Environment

Even when a view doesn't read the changed key, SwiftUI checks all environment readers.

### 14. Off-Main-Thread Closures

`Shape.path()`, `visualEffect`, `Layout`, `onGeometryChange` closures may run off main thread. Capture values instead of accessing `@MainActor` state:

```swift
// BAD
.visualEffect { content, geometry in
    content.blur(radius: self.pulse ? 5 : 0)
}

// GOOD
.visualEffect { [pulse] content, geometry in
    content.blur(radius: pulse ? 5 : 0)
}
```

### 15. Avoid Creating Objects in body

```swift
// BAD — creates formatter every body call
var body: some View {
    let formatter = DateFormatter()
    ...
}

// GOOD — use FormatStyle
Text(Date.now, format: .dateTime.day().month().year())
```

### 16. Scroll Performance

- Use `scrollContentBackground(.visible)` for opaque static backgrounds
- Use `.scrollIndicators(.hidden)` over `showsIndicators: false`

### 17. Avoid Escaping @ViewBuilder Closures

Store built view results (`@ViewBuilder let content: Content`) instead of closures.

## Debugging View Updates

```swift
#if DEBUG
let _ = Self._logChanges()  // iOS 17+: logs to com.apple.SwiftUI subsystem
#endif
```

Prints which properties changed. `@self` means value changed, `@identity` means view was recycled.

## Equatable Views

For views with expensive bodies:

```swift
struct ExpensiveView: View, Equatable {
    let data: SomeData
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.data.id == rhs.data.id
    }
    var body: some View { ... }
}

ExpensiveView(data: data).equatable()
```

## Checklist

- [ ] State updates check for value changes before assigning
- [ ] Hot paths minimize state updates
- [ ] Only needed values passed to views
- [ ] Large lists use `LazyVStack`/`LazyHStack`
- [ ] No object creation in `body`
- [ ] Heavy computation moved out of `body`
- [ ] ForEach uses stable identity (not `.indices`)
- [ ] No `AnyView` in list rows
- [ ] Sendable closures capture values instead of accessing @MainActor state
- [ ] `.task()` preferred over `onAppear` for async work
