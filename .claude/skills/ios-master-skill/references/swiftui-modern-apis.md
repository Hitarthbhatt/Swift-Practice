# Modern SwiftUI API Reference

## Always Use (iOS 15+)

### Compact Replacements

| Deprecated | Recommended | Notes |
|-----------|-------------|-------|
| `navigationBarTitle(_:)` | `navigationTitle(_:)` | |
| `navigationBarItems(...)` | `toolbar { ToolbarItem(...) }` | Structural change |
| `navigationBarHidden(_:)` | `toolbarVisibility(.hidden, for: .navigationBar)` | |
| `statusBar(hidden:)` | `statusBarHidden(_:)` | |
| `edgesIgnoringSafeArea(_:)` | `ignoresSafeArea(_:edges:)` | |
| `colorScheme(_:)` | `preferredColorScheme(_:)` | |
| `foregroundColor(_:)` | `foregroundStyle(_:)` | |
| `cornerRadius(_:)` | `clipShape(.rect(cornerRadius:))` | |
| `actionSheet(...)` | `confirmationDialog(...)` | |
| `alert(isPresented:content:)` | `alert(_:isPresented:actions:message:)` | |
| `autocapitalization(_:)` | `textInputAutocapitalization(_:)` | `.never` replaces `.none` |
| `accessibility(label:)` etc. | `accessibilityLabel()` etc. | Dedicated modifiers |
| `TextField` `onCommit`/`onEditingChanged` | `onSubmit` + `focused` | |
| `animation(_:)` (no value) | `animation(_:value:)` | Back-deploys to iOS 13+ |
| Manual `EnvironmentKey` | `@Entry` macro | Back-deploys (Xcode 16+) |
| `overlay(_:alignment:)` | `overlay(alignment:content:)` | Use trailing closure form |
| `.navigationBarLeading`/`.navigationBarTrailing` | `.topBarLeading`/`.topBarTrailing` | Toolbar placements |
| `Text` concatenation with `+` | Text interpolation: `Text("\(red)\(blue)")` | |

### Presentation

Always use `.confirmationDialog(_:isPresented:actions:message:)` and `.alert(_:isPresented:actions:message:)`:

```swift
.alert("Delete Item?", isPresented: $showAlert) {
    Button("Delete", role: .destructive) { deleteItem() }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("This action cannot be undone.")
}
```

### Text Input

Always use `onSubmit(of:_:)` and `focused(_:equals:)`:

```swift
@FocusState private var isFocused: Bool

TextField("Search", text: $query)
    .focused($isFocused)
    .onSubmit { performSearch() }
```

### Custom Environment Values

Always use `@Entry` macro:

```swift
extension EnvironmentValues {
    @Entry var myCustomValue: String = "Default value"
}
```

## iOS 16+

| Deprecated | Recommended |
|-----------|-------------|
| `NavigationView` | `NavigationStack` / `NavigationSplitView` |
| `accentColor(_:)` | `tint(_:)` |
| `disableAutocorrection(_:)` | `autocorrectionDisabled(_:)` |
| `UIPasteboard.general` | `PasteButton` for user-initiated paste |

## iOS 17+

| Deprecated | Recommended |
|-----------|-------------|
| `ObservableObject` | `@Observable` |
| `onChange(of:perform:)` | `onChange(of:) { }` or `onChange(of:) { old, new in }` |
| `MagnificationGesture` | `MagnifyGesture` |
| `RotationGesture` | `RotateGesture` |
| `coordinateSpace(name:)` | `coordinateSpace(.named(...))` |

Consider `containerRelativeFrame()`, `visualEffect()`, or `onGeometryChange(for:of:action:)` as alternatives to `GeometryReader`.

## iOS 18+

| Deprecated | Recommended |
|-----------|-------------|
| `tabItem(_:)` | `Tab` API |

Use `@Previewable` for dynamic properties in `#Preview`.

## iOS 26+

| Deprecated | Recommended |
|-----------|-------------|
| Manual `animatableData` | `@Animatable` macro |
| `presentationBackground(_:)` on sheets | Default Liquid Glass sheet material |
| Custom toolbar background hacks | `scrollEdgeEffectStyle(_:for:)` |
| Hand-wrapped `WKWebView` via UIViewRepresentable | Native `WebView` (import WebKit) |

### New iOS 26 APIs

- `scrollEdgeEffectStyle(_:for:)` — scroll edge behavior
- `backgroundExtensionEffect()` — edge-extending blurred backgrounds
- `tabBarMinimizeBehavior(_:)` — tab bar minimization on scroll
- `tabViewBottomAccessory` — persistent controls above tab bar
- `Tab(role: .search)` — search tab that morphs into search field
- `ToolbarSpacer` — grouping toolbar items
- `sharedBackgroundVisibility(.hidden)` — remove glass group background
- `controlSize(.extraLarge)` — extra-large buttons
- `searchToolbarBehavior(.minimizable)` — minimized search button
- `TextEditor` with `AttributedString` binding for rich text editing
- `navigationZoomTransition` — morph sheets from source view
- `dragContainer` — multi-item drag operations
- `Slider` tick marks and `sliderNeutralValue`

### Additional Modern API Rules

- Use `sensoryFeedback()` over `UIImpactFeedbackGenerator` for haptics.
- Use generated symbol asset API: `Image(.avatar)` over `Image("avatar")`.
- Use `.scrollIndicators(.hidden)` over `showsIndicators: false`.
- Use `ForEach(items.enumerated(), id: \.element.id)` directly (no array conversion).
- Fill and stroke shapes with two chained modifiers (no overlay needed, iOS 17+).
- Prefer `contentUnavailableView` for empty/missing data over custom designs.
- Use `ContentUnavailableView.search` for empty search results.
- If using `ObservableObject`, add explicit `import Combine`.

### Using ObservableObject

If `ObservableObject` is absolutely required (e.g., Combine debouncer), always ensure `import Combine` is added explicitly — it is no longer re-exported from SwiftUI.
