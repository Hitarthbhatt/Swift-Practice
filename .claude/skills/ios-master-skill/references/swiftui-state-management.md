# SwiftUI State Management

## Property Wrapper Selection Guide

| Wrapper | Use When | Notes |
|---------|----------|-------|
| `@State` | Internal view state that triggers updates | Must be `private` |
| `@Binding` | Child view needs to **modify** parent's state | Don't use for read-only |
| `@Bindable` | iOS 17+: View receives `@Observable` object and needs bindings | For injected observables |
| `let` | Read-only value passed from parent | Simplest option |
| `var` | Read-only value watched via `.onChange()` | For reactive reads |

**Legacy (Pre-iOS 17):**

| Wrapper | Use When |
|---------|----------|
| `@StateObject` | View owns an `ObservableObject` instance |
| `@ObservedObject` | View receives an `ObservableObject` from outside |

## @Observable (Preferred for iOS 17+)

Always prefer `@Observable` over `ObservableObject` for new code.

```swift
@Observable
@MainActor
final class DataModel {
    var name = "Some Name"
    var count = 0
}

struct MyView: View {
    @State private var model = DataModel()

    var body: some View {
        VStack {
            TextField("Name", text: $model.name)
            Stepper("Count: \(model.count)", value: $model.count)
        }
    }
}
```

**Critical rules:**
- `@Observable` classes must be marked `@MainActor` (unless the project uses MainActor default isolation).
- When a view *owns* an `@Observable` object, always use `@State` — not `let`. Without `@State`, SwiftUI may recreate the instance on parent redraws.
- Use `@Bindable` for injected `@Observable` objects needing bindings.
- Nested `@Observable` objects work automatically (unlike `ObservableObject`).

## Property Wrappers Inside @Observable Classes

`@Observable` macro conflicts with other property wrappers. Always annotate with `@ObservationIgnored`:

```swift
@Observable
@MainActor
final class SettingsModel {
    @ObservationIgnored @AppStorage("username") var username = ""
    var isLoading = false // Regular properties work fine
}
```

Applies to `@AppStorage`, `@SceneStorage`, `@Query`, etc.

## @State Rules

- Always mark `@State` as `private`.
- Never declare passed values as `@State` — they only accept initial values and ignore subsequent parent updates.
- `@State` can store non-observable class instances as a cache (e.g., `CIContext`).

```swift
// WRONG - child ignores parent updates
struct ChildView: View {
    @State var item: Item  // Shows initial value forever!
}

// CORRECT
struct ChildView: View {
    let item: Item
}
```

## @Binding Rules

- Use only when child needs to **modify** parent state.
- If child only reads, use `let` instead.
- Strongly avoid creating bindings with `Binding(get:set:)`. Use `@State` with `onChange()` instead.

## @AppStorage

- Never use `@AppStorage` inside `@Observable` classes (even with `@ObservationIgnored`, it won't trigger view updates through Observation).
- Never store usernames, passwords, or sensitive data in `@AppStorage`. Use the Keychain.

## Numeric TextField Binding

```swift
TextField("Enter your score", value: $score, format: .number)
    .keyboardType(.numberPad)  // .decimalPad for floating-point
```

## @FocusState

- Single field: `@FocusState private var isFocused: Bool`
- Multiple fields: use a `Hashable` enum optional

```swift
enum Field: Hashable { case name, email, password }
@FocusState private var focusedField: Field?

TextField("Name", text: $name)
    .focused($focusedField, equals: .name)
```

## Environment with @Observable (Preferred)

```swift
@Observable
@MainActor
final class AppState {
    var isLoggedIn = false
}

// Inject
ContentView().environment(AppState())

// Access
struct ChildView: View {
    @Environment(AppState.self) private var appState
}
```

## Decision Flowchart

```
Is this value owned by this view?
├─ YES: Is it a simple value type?
│       ├─ YES → @State private var
│       └─ NO (class): Use @Observable → @State private var
│
└─ NO (passed from parent):
    ├─ Does child need to MODIFY it?
    │   ├─ YES → @Binding var
    │   └─ NO: Does child need BINDINGS to properties?
    │       ├─ YES (@Observable) → @Bindable var
    │       └─ NO: Does child react to changes?
    │           ├─ YES → var + .onChange()
    │           └─ NO → let
```

## Data Flow Rules

- Make structs conform to `Identifiable` rather than using `id: \.someProperty`.
- All shared data should use `@Observable` classes with `@State` (ownership) and `@Bindable`/`@Environment` (passing).
- Strongly avoid `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject` unless unavoidable.
