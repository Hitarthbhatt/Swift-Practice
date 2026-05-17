# Topic 6 — LRU Cache

Classic algo question. O(1) get/put via dict + doubly-linked list.

## Files
- `LRUCache.swift` — generic `LRUCache<Key, Value>`. Dict node refs + DLL for eviction order.
- `LRUCacheViewModel.swift` — `@Observable` wrapper, ops log.
- `LRUCacheDemoView.swift` — UI for put/get/evict visualization.

## Invariants
- `count <= capacity`.
- Head = MRU, tail = LRU.
- Get/put both move node to head.
