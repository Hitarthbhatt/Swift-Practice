---
name: ios-master-skill
description: Production-grade iOS skill for writing, reviewing, and improving Swift/SwiftUI/SwiftData code with modern concurrency, testing, performance, accessibility, and iOS 26+ Liquid Glass. Use for any iOS development task.
version: "1.0"
---

# iOS Master Skill

Write, review, and improve iOS application code for correctness, modern API usage, performance, accessibility, and adherence to Apple platform conventions. Report only genuine problems — do not nitpick or invent issues.

## Core Principles

- **iOS 26** is the current release. Default deployment target for new apps.
- **Swift 6.2** or later with strict concurrency checking.
- Prefer **SwiftUI** over UIKit unless UIKit is explicitly requested.
- Prefer **SwiftData** over Core Data for persistence.
- Prefer **Swift Testing** over XCTest for new unit/integration tests (XCTest required for UI tests).
- Prefer **Swift Concurrency** (`async`/`await`, actors, task groups) over GCD for new code.
- Do **not** introduce third-party frameworks without asking first.
- Organize code by **feature folders**. One type per file.
- Facts and best practices over architectural opinions — we don't enforce MVVM, VIPER, etc.

## Workflow Decision Tree

### 1) Review existing code
1. Check for deprecated APIs using `references/swiftui-modern-apis.md`.
2. Validate state management using `references/swiftui-state-management.md`.
3. Check view structure and composition using `references/swiftui-views-and-composition.md`.
4. Ensure performance patterns are applied using `references/swiftui-performance.md`.
5. Check navigation and presentation using `references/swiftui-navigation.md`.
6. Validate animation patterns using `references/swiftui-animation.md`.
7. Validate accessibility and HIG compliance using `references/swiftui-accessibility-and-design.md`.
8. Check Liquid Glass usage (if iOS 26+) using `references/swiftui-liquid-glass.md`.
9. Scan concurrency code for correctness using `references/swift-concurrency.md`.
10. Cross-check concurrency against bug patterns using `references/swift-concurrency-patterns.md`.
11. Validate SwiftData models and queries using `references/swiftdata.md`.
12. Review tests for Swift Testing best practices using `references/swift-testing.md`.
13. Validate Swift language usage using `references/swift-language.md`.
14. Final hygiene check using `references/code-hygiene.md`.

### 2) Write or improve code
Follow the same rules but make changes directly instead of returning a findings report. Load only the relevant reference files for the task.

### 3) Diagnose concurrency issues
1. Analyze `Package.swift` or `.pbxproj` for language mode, strict concurrency, default isolation, upcoming features.
2. Capture exact diagnostics and identify isolation boundaries.
3. Route to `references/swift-concurrency.md` or `references/swift-concurrency-patterns.md`.

## Output Format

When reviewing, organize findings by file. For each issue:

1. State the file and relevant line(s).
2. Name the rule being violated.
3. Show a brief before/after code fix.

Skip files with no issues. End with a prioritized summary of the most impactful changes.

### Example

#### ContentView.swift

**Line 12: Use `foregroundStyle()` instead of `foregroundColor()`.**

```swift
// Before
Text("Hello").foregroundColor(.red)

// After
Text("Hello").foregroundStyle(.red)
```

**Line 24: Icon-only button is inaccessible to VoiceOver.**

```swift
// Before
Button(action: addUser) {
    Image(systemName: "plus")
}

// After
Button("Add User", systemImage: "plus", action: addUser)
```

**Line 45: Actor reentrancy — state may change across `await`.**

```swift
// Before
actor Cache {
    var items: [String: Data] = [:]
    func fetch(_ key: String) async throws -> Data {
        if items[key] == nil {
            items[key] = try await download(key)
        }
        return items[key]!
    }
}

// After
actor Cache {
    var items: [String: Data] = [:]
    func fetch(_ key: String) async throws -> Data {
        if let existing = items[key] { return existing }
        let data = try await download(key)
        items[key] = data
        return data
    }
}
```

#### Summary

1. **Accessibility (high):** Button on line 24 is invisible to VoiceOver.
2. **Concurrency (high):** Actor reentrancy bug on line 45 may crash.
3. **Deprecated API (medium):** `foregroundColor()` on line 12 should be `foregroundStyle()`.

## References

- `references/swiftui-modern-apis.md` — Deprecated-to-modern API transitions (iOS 15+ through iOS 26+)
- `references/swiftui-state-management.md` — Property wrappers, @Observable, data flow, and environment
- `references/swiftui-views-and-composition.md` — View structure, extraction, container patterns, UIViewRepresentable
- `references/swiftui-performance.md` — Performance optimization, anti-patterns, lazy loading, debugging
- `references/swiftui-navigation.md` — NavigationStack, NavigationSplitView, sheets, alerts, dialogs
- `references/swiftui-animation.md` — Implicit/explicit animations, phase/keyframe, @Animatable, transitions
- `references/swiftui-accessibility-and-design.md` — Dynamic Type, VoiceOver, HIG, accessible design
- `references/swiftui-liquid-glass.md` — iOS 26+ Liquid Glass APIs, GlassEffectContainer, fallbacks
- `references/swift-concurrency.md` — Actors, structured/unstructured tasks, async streams, cancellation, bridging, Swift 6.2 features
- `references/swift-concurrency-patterns.md` — Bug patterns, diagnostics, hotspots, migration, interop
- `references/swiftdata.md` — Models, relationships, predicates, CloudKit, indexing, class inheritance
- `references/swift-testing.md` — Swift Testing rules, async tests, parameterized tests, new features, XCTest migration
- `references/swift-language.md` — Modern Swift idioms, formatting, string handling, concurrency basics
- `references/code-hygiene.md` — Security, secrets, localization, linting, testability
