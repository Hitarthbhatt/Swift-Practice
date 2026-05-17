# SwiftUI Animation

## Implicit Animations

Always use `.animation(_:value:)` with value parameter:

```swift
// GOOD
Rectangle()
    .frame(width: isExpanded ? 200 : 100, height: 50)
    .animation(.spring, value: isExpanded)

// BAD — deprecated, animates all changes
.animation(.spring)
```

Place animation **after** the properties it should animate.

## Explicit Animations

Use `withAnimation` for event-driven changes:

```swift
Button("Toggle") {
    withAnimation(.spring) {
        isExpanded.toggle()
    }
}
```

**When to use which:**
- **Implicit**: Animations tied to specific value changes
- **Explicit**: Event-driven animations (taps, gestures)

## Chaining Animations

Use `completion` closure (not `DispatchQueue` delays):

```swift
withAnimation {
    scale = 2
} completion: {
    withAnimation {
        scale = 1
    }
}
```

## Selective Animation

```swift
Rectangle()
    .frame(width: isExpanded ? 200 : 100, height: 50)
    .animation(.spring, value: isExpanded)  // Animate size
    .foregroundStyle(isExpanded ? .blue : .red)
    .animation(nil, value: isExpanded)       // Don't animate color
```

## Performance

- Prefer **transforms** (`offset`, `scaleEffect`, `rotationEffect`) over **layout changes** (`frame`, `padding`).
- Scope animations narrowly (not at root level).
- Avoid animating in hot paths (scroll handlers).
- Gate by thresholds when needed.

## Timing Curves

| Curve | Use Case |
|-------|----------|
| `.spring` | Interactive elements, most UI |
| `.easeInOut` | Appearance changes |
| `.bouncy` | Playful feedback (iOS 17+) |
| `.linear` | Progress indicators only |

## Disabling Animations

```swift
.transaction { $0.animation = nil }     // Remove animation
.transaction { $0.disablesAnimations = true }  // Prevent override
```

## Phase Animations (iOS 17+)

Multi-step sequences:

```swift
enum BouncePhase: CaseIterable {
    case initial, up, down, settle
    var scale: CGFloat {
        switch self {
        case .initial: 1.0; case .up: 1.2; case .down: 0.9; case .settle: 1.0
        }
    }
}

Circle()
    .phaseAnimator(BouncePhase.allCases, trigger: trigger) { content, phase in
        content.scaleEffect(phase.scale)
    }
```

## Keyframe Animations (iOS 17+)

Precise timing with parallel tracks:

```swift
Button("Bounce") { trigger += 1 }
    .keyframeAnimator(initialValue: AnimationValues(), trigger: trigger) { content, value in
        content.scaleEffect(value.scale).offset(y: value.offset)
    } keyframes: { _ in
        KeyframeTrack(\.scale) {
            SpringKeyframe(1.2, duration: 0.15)
            SpringKeyframe(1.0, duration: 0.15)
        }
        KeyframeTrack(\.offset) {
            LinearKeyframe(-20, duration: 0.15)
            LinearKeyframe(0, duration: 0.25)
        }
    }
```

Keyframe types: `CubicKeyframe`, `LinearKeyframe`, `SpringKeyframe`, `MoveKeyframe`.

## Completion Handlers (iOS 17+)

```swift
withAnimation(.spring) {
    isExpanded.toggle()
} completion: {
    showNextStep = true
}
```

For reexecution, use `.transaction(value:)`:

```swift
.transaction(value: bounceCount) { transaction in
    transaction.animation = .spring
    transaction.addAnimationCompletion { message = "Done" }
}
```

## @Animatable Macro (iOS 26+)

Replaces manual `animatableData`:

```swift
@Animatable
struct Wedge: Shape {
    var startAngle: Angle
    var endAngle: Angle
    @AnimatableIgnored var drawClockwise: Bool

    func path(in rect: CGRect) -> Path { /* ... */ }
}
```

## Animation Precedence

Implicit animations override explicit (later in view tree wins):

```swift
Button("Tap") {
    withAnimation(.linear) { flag.toggle() }
}
.animation(.bouncy, value: flag)  // .bouncy wins!
```

## Transitions

- Transitions require animations **outside** the conditional structure.
- Prefer transforms over layout changes for performance.

## Reduce Motion

Respect `@Environment(\.accessibilityReduceMotion)`. Replace motion-based animations with opacity.
