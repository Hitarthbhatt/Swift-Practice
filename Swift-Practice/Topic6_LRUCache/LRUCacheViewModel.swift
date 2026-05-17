import Foundation

struct CacheEntry: Identifiable {
    let id: String
    let key: Int
    let value: String
    let position: Int   // 0 = MRU
}

@Observable @MainActor
final class LRUCacheViewModel {
    // Cache state
    var entries: [CacheEntry] = []
    var hits: Int = 0
    var misses: Int = 0
    var evictions: Int = 0
    var lastEvicted: Int? = nil
    var lastResult: String = "—"
    var capacity: Int = 4 { didSet { resetCache() } }

    // Input
    var selectedKey: Int = 0
    var inputValue: String = "A"

    private var cache = LRUCache<Int, String>(capacity: 4)

    init() { resetCache() }

    func get() {
        let result = cache.get(selectedKey)
        hits = cache.hits
        misses = cache.misses
        if let v = result {
            lastResult = "HIT → \"\(v)\""
        } else {
            lastResult = "MISS (key \(selectedKey) not in cache)"
        }
        refreshEntries()
    }

    func put() {
        let evicted = cache.put(selectedKey, inputValue)
        evictions = cache.evictions
        lastEvicted = evicted
        lastResult = evicted != nil
            ? "PUT key \(selectedKey) → evicted key \(evicted!)"
            : "PUT key \(selectedKey) = \"\(inputValue)\""
        refreshEntries()
    }

    func clear() {
        cache.clear()
        lastResult = "Cache cleared"
        lastEvicted = nil
        hits = 0; misses = 0; evictions = 0
        refreshEntries()
    }

    private func resetCache() {
        cache = LRUCache<Int, String>(capacity: capacity)
        hits = 0; misses = 0; evictions = 0
        lastResult = "—"; lastEvicted = nil
        refreshEntries()
    }

    private func refreshEntries() {
        entries = cache.orderedEntries().enumerated().map { i, pair in
            CacheEntry(id: "\(pair.key)", key: pair.key, value: pair.value, position: i)
        }
    }

    var hitRate: String {
        let total = hits + misses
        guard total > 0 else { return "—" }
        return String(format: "%.0f%%", Double(hits) / Double(total) * 100)
    }
}
