# iOS System Design Interview Prep

## Rules
- Use `@Observable`, `@State`, `NavigationStack`, Swift Concurrency — never legacy equivalents
- One sentence max after completing a task. No summaries, no recaps, no tables of "what was done"
- Never invoke heavy skills (ios-master-skill, brainstorming) without asking first
- No docstrings, comments, or type annotations on unchanged code
- No error handling for impossible cases; no speculative abstractions

## Project
Topic-by-topic iOS system design for senior/staff interview prep. Based on Andrey Tech's Mind Map v1.1.

## Folder convention
`Topic{N}_{Name}/` — Xcode 16 synchronized groups, new files auto-discovered.

## Progress
- ✅ Topic 1: Mobile Domain
- ✅ Topic 2: Concurrency & Data Binding
- ✅ Topic 3: Networking (REST, async/await, Combine)
- ✅ Topic 4: Realtime Networking (HTTP Polling, SSE, WebSockets, Push Notifications)
- ✅ Topic 5: Data Races (Unprotected, SerialQueue, NSLock, Semaphore, Actor, @MainActor, @unchecked Sendable)
- ✅ Topic 6: LRU Cache
- ✅ Topic 7: Concurrent Image Loader (actor, dedup, NSCache, AsyncSemaphore)
- ✅ Topic 8: Network Resilience (ExponentialBackoff, LinearBackoff, CircuitBreaker, OAuth refresh)
- ✅ Topic 9: Performance — Infinite Image Feed (UICollectionView Compositional Layout, Diffable DS, Prefetching, Clean Architecture)
- 🚧 Topic 10: Offline & Sync
  - ✅ Queueing (SwiftData persistent op queue, per-entity FIFO, idempotency keys, crash recovery, dead-letter)
  - ⬜ Conflict resolution
  - ⬜ Background retry
  - ⬜ Batched Requests
  - ⬜ Resumable Uploads / Downloads
  - ⬜ Prefetching
- ⬜ Topic 11: Interview Strategy

## Remaining topics (from mind map)
**3** (partial): GraphQL, gRPC, Pagination, Long-Polling
**11**: Interview strategy, C4 Model, trade-offs
