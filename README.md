# Swift-Practice — iOS System Design Interview Prep

> Topic-by-topic, production-grade SwiftUI / Swift Concurrency code samples for senior & staff iOS interviews. Based on Andrey Tech's Mind Map v1.1.

Every topic is a self-contained Xcode group with its own demo view, view model, and `CLAUDE.md` design notes. Built on **Xcode 16 synchronized groups** — drop a `.swift` file anywhere under `Swift-Practice/` and it gets compiled, no project edits required.

---

## Stack

- **iOS 17+** target (modern observability + concurrency only)
- `@Observable` / `@State` / `NavigationStack` — no `ObservableObject` / `NavigationView`
- Swift Concurrency (`async/await`, `actor`, `Task`, `AsyncStream`) — no completion handlers
- SwiftData where persistence is needed
- Combine retained only where the topic explicitly compares paradigms

---

## Topics

| # | Topic | Status | Highlights |
|---|---|---|---|
| 1 | UI & Navigation | done | `NavigationStack`, coordinator pattern, UIKit interop |
| 2 | Concurrency & Data Binding | done | GCD vs OperationQueue vs async/await vs actors |
| 3 | Networking | done | Async/Combine REST clients **+** Adapter / Retrier / Observer interceptor chain |
| 4 | Realtime Networking | done | HTTP polling, SSE, WebSockets, APNs push |
| 5 | Data Races | done | 7 strategies side-by-side: SerialQueue, NSLock, Semaphore, Actor, `@MainActor`, `@unchecked Sendable` |
| 6 | LRU Cache | done | Doubly-linked list + hashmap, O(1) ops |
| 7 | Concurrent Image Loader | done | Actor + dedup via `[URL: Task]`, `NSCache`, `AsyncSemaphore` |
| 8 | Network Resilience | done | Exponential / linear backoff, circuit breaker, OAuth refresh |
| 9 | Performance — Infinite Feed | done | `UICollectionViewCompositionalLayout` + Diffable DS + prefetching, Clean Architecture |
| 10 | Offline & Sync | partial | SwiftData persistent op queue, idempotency keys, crash recovery, dead-letter |
| 11 | Audio Streaming | done | HLS, `AVPlayer`, multi-bitrate, play/pause/seek/next/prev |
| 12 | Interview Strategy | todo | C4 model, trade-off framework |

---

## Project layout

```
Swift-Practice/
├── Topic1_UINavigation/
├── Topic2_ConcurrencyBinding/
├── Topic3_Networking/
│   ├── NetworkError.swift           # shared error enum
│   ├── NetworkInterceptor.swift     # shared protocols
│   ├── REST/                        # AsyncNetworkClient, CombineNetworkClient, demo
│   └── Interceptors/                # APIClient + Auth/Header/Logging/Retry, MockTransport
├── Topic4_RealtimeNetworking/
├── Topic5_DataRaces/
├── Topic6_LRUCache/
├── Topic7_ConcurrentImageLoader/
├── Topic8_NetworkResilience/
├── Topic9_InfiniteImageFeed/
├── Topic10_OfflineSync/
│   └── Queueing/
├── Topic11_AudioStreaming/
└── Topic12_*/                       # TBD
```

Every topic folder ships a `CLAUDE.md` — read that first. Each one summarises the design decisions, files, and interview talking points so you can pattern-match quickly.

---

## Patterns you'll see in this repo

**Concurrency**
- Actor + in-flight `Task` dedup (Topic 7, 8 auth refresh)
- `AsyncSemaphore` to cap parallel work (no GCD)
- `AsyncStream` to bridge `Sendable` observers into `@MainActor` view models
- Re-checking invariants after every `await` to dodge actor reentrancy bugs

**Networking**
- `RequestAdapter` mutates → `RequestRetrier` decides → `NetworkEventObserver` reads. Three single-purpose roles, composable, individually testable.
- Idempotent-verb retry only, exponential backoff with jitter.
- 401 refresh deduped via actor (no thundering herd).
- Transport injection (`URLSession` in prod, `MockTransport` in tests — no `URLProtocol` subclass needed).

**Architecture**
- Clean Architecture in Topic 9 (DI, repositories, use cases)
- Coordinator pattern in Topic 1
- View model owns the chain wiring; views stay declarative

---

## Run it

```bash
git clone https://github.com/Hitarthbhatt/Swift-Practice.git
cd Swift-Practice
open Swift-Practice.xcodeproj
```

Pick the `Swift-Practice` scheme, run on any iOS 17+ simulator. Root menu lists every topic — tap to launch the demo.

---

## Interview rationale (the *why* behind the repo)

Most "iOS interview repos" stop at LeetCode in Swift. This one targets the part candidates actually fail: **system design for mobile**. Each topic is structured the way the answer should sound on a whiteboard —

1. Problem statement
2. Constraints / trade-offs
3. Chosen pattern + alternatives rejected
4. Failure modes (cancellation, races, retries, backpressure)
5. Test strategy

The `CLAUDE.md` in each folder is the cheat sheet for that talk.

---

## License

MIT — copy what's useful.
