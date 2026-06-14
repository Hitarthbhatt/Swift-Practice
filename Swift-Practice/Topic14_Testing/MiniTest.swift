import Foundation

// A tiny XCTest stand-in so tests RUN inside the app (no separate test target needed).
// The method names mirror XCTest 1:1 so the syntax you practice here is the real thing.
//   run(_:)        ↔ func testXxx() in an XCTestCase
//   assertEqual    ↔ XCTAssertEqual
//   assertTrue     ↔ XCTAssertTrue
//   assertThrows   ↔ XCTAssertThrowsError
//   fail           ↔ XCTFail

@Observable
final class MiniTest {
    struct Result: Identifiable {
        let id = UUID()
        let name: String
        let passed: Bool
        let detail: String
    }

    private(set) var results: [Result] = []
    private var failures: [String] = []

    var passed: Int { results.filter(\.passed).count }
    var failed: Int { results.filter { !$0.passed }.count }

    func reset() { results = []; failures = [] }

    func run(_ name: String, _ body: () async throws -> Void) async {
        failures = []
        do { try await body() } catch { failures.append("threw \(error)") }
        results.append(Result(name: name, passed: failures.isEmpty,
                              detail: failures.joined(separator: " · ")))
    }

    func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "") {
        if a != b { failures.append("\(msg.isEmpty ? "" : msg + ": ")expected \(b), got \(a)") }
    }
    func assertTrue(_ cond: Bool, _ msg: String = "assertTrue failed") {
        if !cond { failures.append(msg) }
    }
    func assertNil(_ value: Any?, _ msg: String = "expected nil") {
        if value != nil { failures.append(msg) }
    }
    func fail(_ msg: String) { failures.append(msg) }

    func assertThrows(_ body: () async throws -> Void, _ msg: String = "expected throw") async {
        do { try await body(); failures.append(msg) } catch { /* expected */ }
    }
}
