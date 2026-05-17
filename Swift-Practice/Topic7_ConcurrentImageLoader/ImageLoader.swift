import UIKit

// MARK: - ImageLoader (Actor)
// Responsibilities:
//   1. NSCache lookup — return immediately if cached
//   2. Dedup — if the same URL is already in-flight, await that task (no double download)
//   3. Concurrency limit — AsyncSemaphore(limit:4) blocks excess downloads
//   4. Cancellation — cancel(url:) cancels the underlying Task
//
// Interview: Why actor?
//   inFlight dict is shared mutable state. Actor serializes all reads/writes to it.
//   No manual locking needed — Swift runtime enforces mutual exclusion.
//
// Download flow:
//   load(url) ──▶ cache hit? ──yes──▶ return image
//                    │ no
//                    ▼
//              in-flight task? ──yes──▶ await existing task (dedup)
//                    │ no
//                    ▼
//              create Task ──▶ semaphore.wait() [blocks if 4 active]
//                                   │
//                              URLSession.data()
//                                   │
//                              cache.set() ──▶ semaphore.signal() ──▶ return

enum ImageLoaderError: LocalizedError {
    case failed
    case cancelled
}

actor ImageLoader {
    static let shared = ImageLoader()
    private init() {}

    private let semaphore = AsyncSemaphore(limit: 4)
    private let cache = ImageCacheStore()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    // Observability
    private(set) var activeDownloads: Int = 0
    private(set) var waitingCount: Int = 0

    func load(url: URL) async throws -> UIImage {
        // 1. Cache hit
        if let cached = await cache.get(url) { return cached }

        // 2. Dedup — reuse in-flight task
        if let existing = inFlight[url] {
            return try await existing.value
        }

        // 3. New download task
        waitingCount += 1
        let task = Task<UIImage, Error> {
            await semaphore.wait()
            self.onStartDownload()

            do {
                try Task.checkCancellation()
                let (data, _) = try await URLSession.shared.data(from: url)
                try Task.checkCancellation()
                guard let image = UIImage(data: data) else {
                    throw ImageLoaderError.failed
                }
                await cache.set(image, for: url)
                await self.onFinishDownload()
                return image
            } catch is CancellationError {
                await self.onFinishDownload()
                throw ImageLoaderError.cancelled
            } catch {
                await self.onFinishDownload()
                throw ImageLoaderError.failed
            }
        }

        inFlight[url] = task

        do {
            let image = try await task.value
            inFlight.removeValue(forKey: url)
            return image
        } catch {
            inFlight.removeValue(forKey: url)
            throw error
        }
    }

    func cancel(url: URL) {
        inFlight[url]?.cancel()
        inFlight.removeValue(forKey: url)
    }

    func clearCache() async { await cache.clear() }

    var inFlightCount: Int { inFlight.count }

    // MARK: - Private state tracking

    private func onStartDownload() {
        waitingCount = max(0, waitingCount - 1)
        activeDownloads += 1
    }

    private func onFinishDownload() async {
        activeDownloads = max(0, activeDownloads - 1)
        await semaphore.signal()  // release semaphore slot — next waiter unblocks
    }
}
