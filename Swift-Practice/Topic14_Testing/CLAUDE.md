# Topic 14 — Testing (XCTest patterns)

Runs in-app via a tiny `MiniTest` harness (no separate test target, keeps the hand-built
pbxproj simple). Method names mirror XCTest 1:1 so the practiced syntax is real.

## Files
- `CartUnderTest.swift` — SUT: `Cart` (@Observable) + injected `PriceService` protocol.
- `MockPriceService.swift` — stub (canned prices) + spy (records `calls`) + failure injection.
- `MiniTest.swift` — assert harness: run/assertEqual/assertTrue/assertNil/assertThrows/fail.
- `CartTests.swift` — 7 tests in Arrange-Act-Assert shape (one intentional fail → red).
- `TestingDemoView.swift` — Run button, pass/fail counts, per-test status.

## MiniTest ↔ real XCTest
| here | XCTest |
|---|---|
| `await t.run("x") { }` | `func testX() async throws { }` |
| `t.assertEqual(a, b)` | `XCTAssertEqual(a, b)` |
| `t.assertTrue/assertNil` | `XCTAssertTrue / XCTAssertNil` |
| `await t.assertThrows { }` | `XCTAssertThrowsError(try ...)` |
| `t.fail("m")` | `XCTFail("m")` |

## Real XCTest you should know
- `class FooTests: XCTestCase`; `setUp()/tearDown()` (or async `setUp() async throws`) per test.
- Async: `func test() async throws { let x = await sut.load() }`.
- Callbacks: `let exp = expectation(description:); ... exp.fulfill(); await fulfillment(of:[exp], timeout: 1)`.
- Perf: `measure { ... }`. Parameterized-ish: loop or Swift Testing `@Test(arguments:)`.
- **Swift Testing** (newer): `import Testing`; `@Test func x() { #expect(a == b) }`, `#require`.

## Key talking points
- Dependency injection (protocol) is what makes code testable — swap real for mock.
- Test doubles: dummy / stub / spy / mock / fake. Spy verifies interactions; stub feeds data.
- Test behavior, not implementation. AAA structure. One reason to fail per test.
- Pyramid: many unit, fewer integration, few UI (XCUITest — slow, flaky, launch the app).
- To add a real target: Xcode → File ▸ New ▸ Target ▸ Unit Testing Bundle (@testable import).
