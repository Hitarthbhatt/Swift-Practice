import SwiftUI

// MARK: - Actors & Sendable
// Interview: "What are actors and how do they prevent data races?"
//
// Actor:
//   - Reference type with built-in synchronization
//   - Only one task can access actor's mutable state at a time
//   - External access requires `await` (actor isolation)
//   - Eliminates data races by design
//
// @MainActor:
//   - Special global actor for UI work
//   - Guarantees code runs on main thread
//   - SwiftUI views are implicitly @MainActor
//
// Sendable:
//   - Protocol marking types safe to pass across concurrency boundaries
//   - Value types (struct, enum) are implicitly Sendable if all properties are
//   - Classes must be final + immutable, or manually @unchecked Sendable
//   - @Sendable for closures that cross boundaries
//
// Senior/Staff:
//   - Actor reentrancy: await can interleave state changes
//   - nonisolated: opt out of actor isolation for non-mutating members
//   - GlobalActor: create your own (e.g., @DatabaseActor)
//   - Sendable checking is now strict by default in Swift 6

// MARK: - Actor: thread-safe counter
actor BankAccount {
    let owner: String
    private(set) var balance: Double

    init(owner: String, balance: Double) {
        self.owner = owner
        self.balance = balance
    }

    func deposit(_ amount: Double) {
        balance += amount
    }

    func withdraw(_ amount: Double) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }

    // nonisolated: no actor isolation needed (immutable data)
    nonisolated var description: String {
        "Account(\(owner))"
    }
}

// MARK: - Actor with reentrancy concern
actor ImageCache {
    private var cache: [String: String] = [:]
    private var inProgress: [String: Task<String, Error>] = [:]

    func image(for url: String) async throws -> String {
        // Check cache first
        if let cached = cache[url] {
            return cached
        }

        // Avoid duplicate fetches — reuse in-progress task
        if let existing = inProgress[url] {
            return try await existing.value
        }

        // Start new fetch
        let task = Task {
            try await Task.sleep(for: .milliseconds(200))
            return "Image(\(url))"
        }
        inProgress[url] = task

        let result = try await task.value

        // ⚠️ REENTRANCY: state may have changed during await!
        // Another task could have modified cache/inProgress while we were suspended
        cache[url] = result
        inProgress[url] = nil
        return result
    }
}

// MARK: - Sendable examples

// ✅ Struct with all Sendable properties — implicitly Sendable
struct UserProfile: Sendable {
    let name: String
    let age: Int
}

// ✅ Final class, immutable — can be Sendable
final class AppConfig: Sendable {
    let apiURL: String
    let timeout: TimeInterval

    init(apiURL: String, timeout: TimeInterval) {
        self.apiURL = apiURL
        self.timeout = timeout
    }
}

// ⚠️ @unchecked Sendable — you're telling compiler "trust me"
// Use only when you manage synchronization yourself (e.g., locks)
final class ThreadSafeCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String] = [:]

    func get(_ key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func set(_ key: String, value: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }
}

// MARK: - Demo View
struct ActorsDemoView: View {
    @State private var log: [String] = []

    var body: some View {
        List {
            Section("Actor Demos") {
                Button("Actor: Concurrent Bank") { Task { await demoBankAccount() } }
                Button("Actor: Image Cache") { Task { await demoImageCache() } }
                Button("MainActor") { Task { await demoMainActor() } }
                Button("Clear Log") { log.removeAll() }
            }

            Section("Log") {
                if log.isEmpty {
                    Text("Tap a demo above").foregroundStyle(.secondary)
                }
                ForEach(Array(log.enumerated()), id: \.offset) { _, entry in
                    Text(entry).font(.caption.monospaced())
                }
            }
        }
        .navigationTitle("Actors & Sendable")
    }

    private func demoBankAccount() async {
        log.append("--- Actor: Bank Account ---")
        let account = BankAccount(owner: "Alice", balance: 1000)

        // Multiple concurrent operations — actor ensures thread safety
        await withTaskGroup(of: Void.self) { group in
            for _ in 1...5 {
                group.addTask { await account.deposit(100) }
            }
            for _ in 1...3 {
                group.addTask { let _ = await account.withdraw(200) }
            }
        }

        let finalBalance = await account.balance
        // Should be 1000 + 500 - 600 = 900 (no data races!)
        log.append("Final balance: \(finalBalance)")

        // nonisolated access — no await needed
        log.append(account.description)
    }

    private func demoImageCache() async {
        log.append("--- Actor: Image Cache ---")
        let cache = ImageCache()

        // Multiple tasks requesting the same URL — deduplication via actor
        await withTaskGroup(of: String.self) { group in
            for i in 1...5 {
                let url = "img\(i % 3)" // some duplicates
                group.addTask {
                    return (try? await cache.image(for: url)) ?? "failed"
                }
            }
            for await result in group {
                log.append(result)
            }
        }
    }

    @MainActor
    private func demoMainActor() async {
        log.append("--- @MainActor ---")
        // This function runs on main thread guaranteed
        log.append("On main thread: \(Thread.isMainThread)")

        // Call background work, then return to main
        let result = await backgroundWork()
        log.append("Result on main: \(result), main: \(Thread.isMainThread)")
    }

    private nonisolated func backgroundWork() async -> String {
        // This runs off the main actor
        try? await Task.sleep(for: .milliseconds(100))
        return "background done"
    }
}

#Preview {
    NavigationStack { ActorsDemoView() }
}
