import UIKit
import SwiftUI

enum ImageState {
    case idle
    case loading
    case loaded(UIImage)
    case failed
    case cancelled
}

@Observable @MainActor
final class ImageLoaderViewModel {
    // 16 picsum images with deterministic seeds
    let urls: [URL] = (1...16).compactMap {
        URL(string: "https://picsum.photos/seed/\($0 * 13)/4000/4000")
    }

    var states: [URL: ImageState] = [:]
    var activeDownloads: Int = 0
    var waitingCount: Int = 0

    private var tasks: [URL: Task<Void, Never>] = [:]
    private let loader = ImageLoader.shared

    func loadAll() {
        for url in urls where tasks[url] == nil {
            load(url)
        }
    }

    func load(_ url: URL) {
        guard tasks[url] == nil else { return }
        states[url] = .loading

        tasks[url] = Task {
            do {
                let image = try await loader.load(url: url)
                states[url] = .loaded(image)
            } catch is CancellationError {
                states[url] = .cancelled
            } catch ImageLoaderError.cancelled {
                states[url] = .cancelled
            } catch ImageLoaderError.failed {
                states[url] = .failed
            } catch {
                states[url] = .failed
            }
            tasks.removeValue(forKey: url)
            await syncCounters()
        }
        Task { await syncCounters() }
    }

    func cancel(_ url: URL) {
        tasks[url]?.cancel()
        tasks.removeValue(forKey: url)
        Task {
            await loader.cancel(url: url)
            await syncCounters()
        }
    }

    func cancelAll() {
        for url in urls { cancel(url) }
    }

    func clearCache() {
        cancelAll()
        Task {
            await loader.clearCache()
            await syncCounters()
        }
        states = [:]
    }

    func reload(_ url: URL) {
        states.removeValue(forKey: url)
        load(url)
    }

    private func syncCounters() async {
        activeDownloads = await loader.activeDownloads
        waitingCount    = await loader.waitingCount
    }
}
