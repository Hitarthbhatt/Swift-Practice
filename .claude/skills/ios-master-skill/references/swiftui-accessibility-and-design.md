# SwiftUI Accessibility & Design

## Accessibility Requirements

### Dynamic Type
- Never force specific font sizes. Use system fonts: `.font(.body)`, `.font(.headline)`.
- For custom sizes: use `@ScaledMetric` (iOS 18-) or `.font(.body.scaled(by:))` (iOS 26+).
- Avoid `.caption2` (extremely small). Use `.caption` sparingly.

### VoiceOver
- **Always** use `Button` over `onTapGesture()` for tappable elements (free VoiceOver support).
- Buttons with image labels **must** include text: `Button("Add User", systemImage: "plus", action: myAction)`.
- Flag icon-only buttons without text labels.
- `Menu` should also include text: `Menu("Options", systemImage: "ellipsis.circle") { }`.
- If `onTapGesture()` must be used, add `.accessibilityAddTraits(.isButton)`.
- Use `Image(decorative:)` or `.accessibilityHidden()` for decorative images.
- Add `accessibilityLabel()` when default labels are unclear.
- Use `accessibilityInputLabels()` for complex/frequently changing button labels.

### Grouping
- Use `accessibilityElement(children: .combine)` to join related elements.
- Use `accessibilityRepresentation` for custom controls that should behave like native ones.

### Color
- Respect `accessibilityDifferentiateWithoutColor` — use icons, patterns, strokes beyond just color.

### Motion
- Respect `accessibilityReduceMotion` — replace motion animations with opacity.

## Human Interface Guidelines

### Design Constants
Prefer placing standard fonts, sizes, colors, spacing, padding, rounding, and animation timings into a shared enum of constants for uniform design.

### Layout Rules
- Never use `UIScreen.main.bounds`. Use `containerRelativeFrame()`, `visualEffect()`, or `GeometryReader`.
- Avoid fixed frames unless content fits — use flexible sizing.
- Minimum tap area: **44x44 points** (strictly enforced by Apple).
- Avoid hard-coded padding/spacing unless specifically requested.
- Views should work in any context (don't assume screen size or presentation style).
- Use relative layout over hard-coded constants.

### Styling
- Use `ContentUnavailableView` for missing/empty data.
- Use `ContentUnavailableView.search` for empty search results.
- Use `Label` over `HStack { Image; Text }` for icon+text.
- Prefer system hierarchical styles (secondary/tertiary) over manual opacity.
- Use `LabeledContent` in `Form` for controls like `Slider`.
- `RoundedRectangle` default is `.continuous` — no need to specify.

### Typography
- Use `bold()` instead of `fontWeight(.bold)` — lets system choose correct weight.
- Use `fontWeight()` only for non-bold weights with good reason.

### Colors
- Avoid `UIColor` in SwiftUI code. Use `Color` or asset catalog colors.

### System Formatting
- Avoid C-style `String(format:)`. Use `Text(value, format: ...)`:
  ```swift
  Text(Date.now, format: .dateTime.day().month().year())
  Text(100, format: .currency(code: "USD"))
  ```

### Person Names
Use `PersonNameComponents` with modern formatting over string interpolation.

### Grammar
Use automatic grammar agreement: `Text("^[\(people) person](inflect: true)")`.
