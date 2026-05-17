# SwiftUI Navigation & Presentation

## Navigation

- Use `NavigationStack` or `NavigationSplitView`. Flag all `NavigationView` usage.
- Prefer `navigationDestination(for:)` for type-safe destinations. Flag `NavigationLink(destination:)`.
- Never mix `navigationDestination(for:)` and `NavigationLink(destination:)` in the same hierarchy.
- `navigationDestination(for:)` must be registered once per data type — flag duplicates.

```swift
NavigationStack {
    List(items) { item in
        NavigationLink(value: item) { Text(item.name) }
    }
    .navigationDestination(for: Item.self) { DetailView(item: $0) }
}
```

## Sheets

- Prefer `sheet(item:)` over `sheet(isPresented:)` for optional data (safely unwraps).
- When using `sheet(item:)` with a single-parameter init: `sheet(item: $item, content: SomeView.init)`.
- Sheets should own their actions and dismiss internally.

## Alerts & Confirmation Dialogs

- Always attach `confirmationDialog()` to the UI that triggers it (enables Liquid Glass source animation).
- Single "OK" button alert: omit the actions closure: `.alert("Title", isPresented: $show) { }`.

```swift
.alert("Delete Item?", isPresented: $showAlert) {
    Button("Delete", role: .destructive) { deleteItem() }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("This action cannot be undone.")
}
```

## iOS 26+ Presentations

- Use `navigationZoomTransition` to morph sheets from source:

```swift
.toolbar {
    ToolbarItem {
        Button("Add", systemImage: "plus") { showSheet = true }
            .navigationTransitionSource(id: "addSheet", namespace: namespace)
    }
}
.sheet(isPresented: $showSheet) {
    AddItemView()
        .navigationTransitionDestination(id: "addSheet", namespace: namespace)
}
```

- Partial-height sheets use Liquid Glass background by default. Consider removing custom `presentationBackground(_:)`.
