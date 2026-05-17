# Code Hygiene

## Security

- **Never** include API keys or secrets in the repository.
- **Never** store usernames, passwords, or sensitive data in `@AppStorage`. Use the Keychain.
- Validate all user input at system boundaries.

## Code Organization

- One type (struct, class, enum) per Swift file. Flag files with multiple types.
- Feature-based folder organization.
- Business logic in services/models, not views.

## Comments & Documentation

- Comments where logic isn't self-evident.
- Don't over-comment obvious code.

## Testing

- Unit tests for core application logic.
- UI tests only where unit tests aren't possible.
- Use Swift Testing for new tests. XCTest for UI tests only.

## Localization

- If using `Localizable.xcstrings`, prefer symbol keys (e.g., "helloWorld") with `extractionState: "manual"`.
- Access via generated symbols: `Text(.helloWorld)`.
- Offer to translate new keys into all supported languages.

## Linting

- If SwiftLint is configured, zero warnings/errors.

## SwiftUI Views

- Test view logic through view models (not views directly).
- `@Observable` view models are directly testable — no protocol wrapper needed.

## Dependencies

- Do not introduce third-party frameworks without asking first.
- If adding Swift Numerics for float tolerance testing, ask permission first.

## Xcode MCP

If configured, prefer Xcode MCP tools:
- `RenderPreview` for preview screenshots
- `DocumentationSearch` for latest Apple docs
