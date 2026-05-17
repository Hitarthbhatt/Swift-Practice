# Liquid Glass (iOS 26+)

**Only adopt when explicitly requested by the user or when building for iOS 26+.**

## Availability

All Liquid Glass APIs require iOS 26+. Always provide fallbacks:

```swift
if #available(iOS 26, *) {
    content.glassEffect(.regular, in: .rect(cornerRadius: 16))
} else {
    content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
}
```

## Core APIs

### glassEffect Modifier

```swift
// Basic
Text("Hello").padding().glassEffect()

// With shape
Text("Rounded").padding().glassEffect(in: .rect(cornerRadius: 16))
Image(systemName: "star").padding().glassEffect(in: .circle)
Text("Capsule").padding(.horizontal, 20).glassEffect(in: .capsule)
```

### Styles

```swift
.glassEffect(.regular)      // Standard
.glassEffect(.prominent)    // Higher contrast
```

### Tinting

```swift
.glassEffect(.regular.tint(.blue))
.glassEffect(.prominent.tint(.red.opacity(0.3)))
```

### Interactivity

Only on elements that respond to user input:

```swift
.glassEffect(.regular.interactive())
.glassEffect(.regular.tint(.blue).interactive())
```

## GlassEffectContainer

**Glass cannot sample other glass.** Wrap grouped glass elements in `GlassEffectContainer` for shared sampling region:

```swift
GlassEffectContainer(spacing: 24) {
    HStack(spacing: 24) {
        GlassChip(icon: "pencil")
        GlassChip(icon: "eraser")
    }
}
```

Container `spacing` must match actual layout spacing.

## Glass Button Styles

```swift
Button("Action") { }.buttonStyle(.glass)
Button("Primary") { }.buttonStyle(.glassProminent)
```

## Morphing Transitions

Use `glassEffectID` with `@Namespace`:

```swift
@Namespace private var animation
@State private var isExpanded = false

GlassEffectContainer {
    if isExpanded {
        ExpandedCard()
            .glassEffect()
            .glassEffectID("card", in: animation)
    } else {
        CompactCard()
            .glassEffect()
            .glassEffectID("card", in: animation)
    }
}
.animation(.smooth, value: isExpanded)
```

Requirements: same `glassEffectID`, same `@Namespace`, wrapped in `GlassEffectContainer`, animation on container.

## Modifier Order (Critical)

Apply `glassEffect` **after** layout and visual modifiers:

```swift
// CORRECT
Text("Label")
    .font(.headline)        // 1. Typography
    .foregroundStyle(.primary) // 2. Color
    .padding()              // 3. Layout
    .glassEffect()          // 4. Glass LAST
```

## Fallback Materials

| Material | Opacity |
|----------|---------|
| `.ultraThinMaterial` | Closest to glass |
| `.thinMaterial` | Slightly more opaque |
| `.regularMaterial` | Standard blur |
| `.thickMaterial` | More opaque |

## Design Notes

- Toolbar icons use **monochrome rendering** by default.
- Sheets use Liquid Glass background by default — remove custom `presentationBackground(_:)`.
- Scroll edge effect blurs content under toolbars — remove custom darkening backgrounds.
- Use `tint(_:)` only to convey meaning, not for visual effect.

## Best Practices

**Do:**
- Use `GlassEffectContainer` for grouped elements
- Apply glass after layout modifiers
- Use `.interactive()` only on tappable elements
- Match container spacing with layout spacing
- Provide material fallbacks for older iOS

**Don't:**
- Apply glass to every element
- Use `.interactive()` on static content
- Mix corner radii arbitrarily
- Apply glass before padding/frame
- Nest `GlassEffectContainer` unnecessarily
- Add custom darkening backgrounds behind toolbars

## Checklist

- [ ] `#available(iOS 26, *)` with fallback
- [ ] `GlassEffectContainer` wraps grouped elements
- [ ] `.glassEffect()` applied after layout modifiers
- [ ] `.interactive()` only on user-interactable elements
- [ ] `glassEffectID` with `@Namespace` for morphing
- [ ] Consistent shapes across feature
