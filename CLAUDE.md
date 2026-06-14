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
`Topic{N}_{Name}/` — Xcode 16 synchronized groups, new files auto-discovered. Each topic folder has its own `CLAUDE.md` — read that first instead of scanning files.

## Topic index
- `Swift-Practice/Topic1_UINavigation/CLAUDE.md`
- `Swift-Practice/Topic2_ConcurrencyBinding/CLAUDE.md`
- `Swift-Practice/Topic3_Networking/CLAUDE.md` (+ `REST/` subfolder)
- `Swift-Practice/Topic4_RealtimeNetworking/CLAUDE.md`
- `Swift-Practice/Topic5_DataRaces/CLAUDE.md`
- `Swift-Practice/Topic6_LRUCache/CLAUDE.md`
- `Swift-Practice/Topic7_ConcurrentImageLoader/CLAUDE.md`
- `Swift-Practice/Topic8_NetworkResilience/CLAUDE.md`
- `Swift-Practice/Topic9_InfiniteImageFeed/CLAUDE.md`
- `Swift-Practice/Topic10_OfflineSync/CLAUDE.md` (+ `Queueing/CLAUDE.md`)
- `Swift-Practice/Topic11_AudioStreaming/CLAUDE.md`
- `Swift-Practice/Topic12_VideoDownload/CLAUDE.md` (+ `BackgroundURLSession/`, `HLSDownload/` subfolders)
- `Swift-Practice/Topic13_DesignPatterns/CLAUDE.md`
- `Swift-Practice/Topic14_Testing/CLAUDE.md`
- `Swift-Practice/Topic15_NetworkInterceptors/CLAUDE.md`

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
- ✅ Topic 11: Audio Streaming (HLS, AVPlayer, multi-bitrate, play/pause/next/prev/seek)
- ✅ Topic 12: Video Download (background URLSession + AVAssetDownload, pause/resume, kill-survival, progress, quality/bitrate, offline playback)
- ✅ Topic 13: Design Patterns (Factory, Builder, Facade, Adapter, Observer, Strategy — iOS scenarios, interactive)
- ✅ Topic 14: Testing (in-app XCTest-style runner, DI, stub/spy mocks, async tests, AAA)
- ✅ Topic 15: Network Interceptors (single-protocol chain — Auth, Retry w/ exp backoff+jitter, Log)

## Remaining topics (from mind map)
**3** (partial): GraphQL, gRPC, Pagination, Long-Polling
**Interview strategy**: C4 Model, trade-offs
