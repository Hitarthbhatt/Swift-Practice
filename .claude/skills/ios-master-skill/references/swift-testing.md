# Swift Testing

Swift Testing does **not** support UI tests — XCTest must be used there.

## Core Rules

### Structs Over Classes
Prefer structs for test suites. Classes only if you need subclassing or deinit.

### @Suite Is Optional
Any type with `@Test` methods is automatically a suite. Only add `@Suite` for naming or traits:
```swift
@Suite(.tags(.networking)) struct APITests { ... }
```

### init/deinit Over setUp/tearDown

```swift
struct PlayerTests {
    let sut: Player
    init() { sut = Player(name: "Alice") }

    @Test func nameIsCorrect() {
        #expect(sut.name == "Alice")
    }
}
```

Initializers can be `async throws`.

### No test Prefix Needed
`userCanLogOut()` is fine — no need for `testUserCanLogOut()`.

### Parallel Execution Is Default
Each test must be independent and order-agnostic.

### @available on Tests, Not Suites
`@available(iOS 26, *)` goes on individual tests, not the suite.

## Assertions

### #expect vs #require

- `#expect` — assert condition, continue on failure
- `#require` — assert condition, **stop test** on failure (throws)

Use `#require` for preconditions:

```swift
@Test func outstandingTasks() throws {
    let sut = try createTestUser(projects: 3)
    try #require(sut.projects.isEmpty == false)
    #expect(sut.outstandingTasksString == "30 items")
}
```

`#require` also unwraps optionals: `let value = try #require(someOptional)`

### Never Use ! in #expect

```swift
// BAD — defeats macro expansion
#expect(!isLoggedIn)

// GOOD — proper evaluation
#expect(isLoggedIn == false)
```

### Throw Testing

Preferred: `do`/`try`/`catch` with `Issue.record()`:

```swift
@Test func playingThrows() {
    do {
        try game.play()
        Issue.record("Expected an error.")
    } catch GameError.notPurchased {
        // success
    } catch {
        Issue.record("Wrong error: \(error)")
    }
}
```

Or `#expect(throws:)` with specific error:

```swift
#expect(throws: GameError.notInstalled) { try game.play() }
#expect(throws: Never.self) { try game.play() }  // Assert no throw
```

Return error for additional validation (Swift 6.1+):

```swift
let error = #expect(throws: GameError.self) { try playGame(at: 22) }
#expect(error == .disallowedTime)
```

## Parameterized Tests

```swift
@Test(arguments: [(32, 0), (212, 100), (-40, -40)])
func fahrenheitToCelsius(values: (input: Double, output: Double)) { ... }
```

At most two argument collections. Two collections form Cartesian product. For pairwise: `zip(c1, c2)`.

## Tags

```swift
extension Tag {
    @Tag static var networking: Self
}

@Test(.tags(.networking)) func fetchProfile() async throws { ... }
```

## Time Limits

**Only `.minutes()` is available** (not `.seconds()`):

```swift
@Test(.timeLimit(.minutes(1))) func loadNames() async { ... }
```

## Serialized Trait

**Only affects parameterized tests.** Does nothing on non-parameterized tests:

```swift
@Test(.serialized, arguments: ["alice", "bob"])
func accountCreation(username: String) async throws { ... }
```

## Async Tests

### confirmation()

Check async events:

```swift
@Test func notificationFires() async {
    await confirmation { confirmed in
        let task = Task {
            for await _ in NotificationCenter.default.notifications(named: .dataDidChange) {
                confirmed()
                break
            }
        }
        await Task.yield()
        NotificationCenter.default.post(name: .dataDidChange, object: nil)
        await task.value
    }
}
```

- `confirmation(expectedCount: 0)` — "event must never happen"
- `confirmation(expectedCount: 5...10)` — range (Swift 6.1+)
- All work must complete before closure returns

### Actor Isolation in Tests

```swift
@MainActor
@Test func viewModelUpdates() async { ... }
```

`confirmation()` and `withKnownIssue()` accept `isolation` parameter.

### Avoid Timing-Based Tests

Never use `Task.sleep` to "wait." Await the actual operation instead.

## Known Issues

```swift
withKnownIssue("Bug #123") {
    // Code that currently fails
}
```

`isIntermittent: true` — passes if no issue, expected failure if issue occurs.

## Test Scoping Traits (Swift 6.1+)

Concurrency-safe shared test configurations:

```swift
struct MockEnvironmentTrait: TestTrait, TestScoping {
    func provideScope(for test: Test, testCase: Test.Case?, performing function: () async throws -> Void) async throws {
        try await Environment.$current.withValue(mockEnv) {
            try await function()
        }
    }
}

extension Trait where Self == MockEnvironmentTrait {
    static var mockEnvironment: Self { Self() }
}

@Test(.mockEnvironment) func fetchUsesTestAPI() async throws { ... }
```

## Exit Tests (Swift 6.2+)

Test `precondition`/`fatalError`:

```swift
@Test func invalidDiceRollsFail() async throws {
    await #expect(processExitsWith: .failure) {
        let _ = Dice().roll(sides: 0)
    }
}
```

## Attachments (Swift 6.2+)

```swift
Attachment.record(result, named: "Character")
```

Supports `String`, `Data`, and `Encodable` types.

## Raw Identifiers (Swift 6.2+)

```swift
@Test
func `Strip HTML tags from string`() { ... }
```

Suggest only — don't adopt by surprise.

## Verification Methods

Use `SourceLocation` for proper error reporting:

```swift
func verify(_ result: (Int, Int), expected: (Int, Int), sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(result.0 == expected.0, sourceLocation: sourceLocation)
    #expect(result.1 == expected.1, sourceLocation: sourceLocation)
}
```

## Bug Tracking

```swift
@Test("Headings italic", .bug(id: 182)) func headingsItalic() { ... }
@Test("Fix", .bug("https://github.com/repo/issues/182")) func fix() { ... }
```

## Mocking Networking

```swift
protocol URLSessionProtocol {
    func data(from url: URL) async throws -> (Data, URLResponse)
}
extension URLSession: URLSessionProtocol { }
```

Create mock, inject into production code. No live networking in unit tests.

## Hidden Dependencies

Inject `URLSession`, `UserDefaults`, etc. Use unique suite for test UserDefaults:

```swift
let suite = "suite-\(UUID().uuidString)"
let ud = UserDefaults(suiteName: suite)
defer { ud?.removePersistentDomain(forName: suite) }
```

## XCTest Migration

| XCTest | Swift Testing |
|--------|--------------|
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertLessThan(a, b)` | `#expect(a < b)` |
| `XCTAssertThrowsError` | `#expect(throws:)` |
| `XCTUnwrap(optional)` | `try #require(optional)` |
| `XCTFail("msg")` | `Issue.record("msg")` |
| `XCTAssertIdentical(a, b)` | `#expect(a === b)` |

Float tolerance: use Swift Numerics `isApproximatelyEqual(to:absoluteTolerance:)`.

## Test Hygiene (FIRST)

- **Fast**: dozens per second
- **Isolated**: no dependency on other tests
- **Repeatable**: same result every time
- **Self-verifying**: unambiguous pass/fail
- **Timely**: written alongside production code

Test generation: happy path, boundary, invalid input, concurrency.
