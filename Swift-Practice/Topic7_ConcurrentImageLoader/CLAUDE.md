# Topic 7 — Concurrent Image Loader

Actor-based loader with dedup, memory cache, concurrency limit.

## Files
- `ImageLoader.swift` — `actor ImageLoader`. In-flight task dedup via `[URL: Task]`. Calls cache + semaphore.
- `ImageCacheStore.swift` — wraps `NSCache<NSURL, UIImage>`.
- `AsyncSemaphore.swift` — async-compatible semaphore (no GCD).
- `ImageLoaderViewModel.swift` — `@Observable` orchestration.
- `ImageLoaderDemoView.swift` — grid UI.

## Key design
- Dedup: concurrent requests for same URL share one `Task`.
- Cache hit short-circuits before network.
- Semaphore caps parallel downloads.
