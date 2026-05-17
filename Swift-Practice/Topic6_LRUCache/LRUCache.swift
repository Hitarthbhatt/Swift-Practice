import Foundation

// MARK: - LRU Cache
// Least Recently Used eviction policy:
//   • GET  → if hit: move to MRU end, return value. If miss: return nil.
//   • PUT  → insert at MRU end. If over capacity: evict from LRU end.
//
// Target complexity: O(1) get + put.
// Data structure: Doubly Linked List + HashMap
//   • HashMap[key] → Node  — O(1) lookup
//   • DLL maintains access order (head = MRU, tail = LRU)
//   • On access: unlink node, reinsert at head — O(1)
//   • On eviction: remove tail — O(1)
//
// Interview: Why not just sort by timestamp? → O(n) eviction.
// Why doubly linked? → Need to unlink a middle node in O(1); requires prev pointer.

final class LRUCache<Key: Hashable, Value> {

    // MARK: - Node (doubly linked list)
    private final class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        init(_ key: Key, _ value: Value) { self.key = key; self.value = value }
    }

    // MARK: - Properties
    let capacity: Int
    private var map: [Key: Node] = [:]
    private var head: Node?     // MRU end
    private var tail: Node?     // LRU end

    // Observability for demo
    private(set) var hits = 0
    private(set) var misses = 0
    private(set) var evictions = 0
    var count: Int { map.count }
    var hitRate: Double { hits + misses == 0 ? 0 : Double(hits) / Double(hits + misses) }

    init(capacity: Int) {
        precondition(capacity > 0, "Capacity must be > 0")
        self.capacity = capacity
    }

    // MARK: - Public API

    func get(_ key: Key) -> Value? {
        guard let node = map[key] else { misses += 1; return nil }
        moveToHead(node)
        hits += 1
        return node.value
    }

    /// Returns the evicted key, if any.
    @discardableResult
    func put(_ key: Key, _ value: Value) -> Key? {
        if let node = map[key] {
            node.value = value
            moveToHead(node)
            return nil
        }
        let node = Node(key, value)
        map[key] = node
        insertAtHead(node)
        if map.count > capacity {
            return evictLRU()
        }
        return nil
    }

    func remove(_ key: Key) {
        guard let node = map.removeValue(forKey: key) else { return }
        unlink(node)
    }

    func clear() {
        map.removeAll(); head = nil; tail = nil
        hits = 0; misses = 0; evictions = 0
    }

    /// Returns entries ordered MRU → LRU.
    func orderedEntries() -> [(key: Key, value: Value)] {
        var result: [(Key, Value)] = []
        var cur = head
        while let node = cur { result.append((node.key, node.value)); cur = node.next }
        return result
    }

    // MARK: - Private helpers

    private func insertAtHead(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil { tail = node }
    }

    private func unlink(_ node: Node) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
        if head === node { head = node.next }
        if tail === node { tail = node.prev }
        node.prev = nil; node.next = nil
    }

    private func moveToHead(_ node: Node) {
        guard head !== node else { return }
        unlink(node)
        insertAtHead(node)
    }

    @discardableResult
    private func evictLRU() -> Key? {
        guard let lru = tail else { return nil }
        unlink(lru)
        map.removeValue(forKey: lru.key)
        evictions += 1
        return lru.key
    }
}
