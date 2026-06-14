import Foundation

// Tests written in the Arrange-Act-Assert shape. Each `run` block = one test method.
// In a real XCTest target these would be `func testAddIncreasesTotal() async throws { ... }`.

enum CartTests {
    static func runAll(into t: MiniTest) async {

        await t.run("add increases total") {
            let mock = MockPriceService(["A": 10])         // arrange
            let cart = Cart(prices: mock)
            try await cart.add("A")                         // act
            t.assertEqual(cart.total, 10)                   // assert
            t.assertEqual(cart.items["A"], 1)
        }

        await t.run("adding same SKU twice sums quantity") {
            let cart = Cart(prices: MockPriceService(["A": 10]))
            try await cart.add("A")
            try await cart.add("A")
            t.assertEqual(cart.items["A"], 2)
            t.assertEqual(cart.total, 20)
        }

        await t.run("remove clears the item") {
            let cart = Cart(prices: MockPriceService(["A": 10, "B": 5]))
            try await cart.add("A")
            try await cart.add("B")
            try await cart.remove("A")
            t.assertNil(cart.items["A"])
            t.assertEqual(cart.total, 5)
        }

        await t.run("spy records the price lookups") {
            let mock = MockPriceService(["A": 10, "B": 5])
            let cart = Cart(prices: mock)
            try await cart.add("A")
            try await cart.add("B")
            // recompute prices every mutation: A, then A+B → 3 lookups total
            t.assertEqual(mock.calls.count, 3)
            t.assertTrue(mock.calls.contains("B"), "B should be priced")
        }

        await t.run("unknown SKU throws StoreError") {
            let cart = Cart(prices: MockPriceService([:]))
            await t.assertThrows { try await cart.add("ghost") }
        }

        await t.run("injected failure propagates") {
            let mock = MockPriceService(["A": 10])
            mock.failSKU = "A"
            let cart = Cart(prices: mock)
            await t.assertThrows { try await cart.add("A") }
        }

        // Deliberately failing test to show red in the UI.
        await t.run("DEMO failing assert (intentional)") {
            let cart = Cart(prices: MockPriceService(["A": 10]))
            try await cart.add("A")
            t.assertEqual(cart.total, 999, "this is meant to fail")
        }
    }
}
