import Foundation

// Facade: one simple call hides a messy multi-step subsystem.

private struct RemoteFetcher {
    func download(_ url: URL) async -> Data { Data("rawbytes".utf8) }
}

private struct PixelDecoder {
    func decode(_ data: Data) -> String { "image(\(data.count)b)" }
}

private final class MemoryStore {
    private var store: [URL: String] = [:]
    func value(for url: URL) -> String? { store[url] }
    func insert(_ value: String, for url: URL) { store[url] = value }
}

final class ImageService {
    private let fetcher = RemoteFetcher()
    private let decoder = PixelDecoder()
    private let store = MemoryStore()

    func load(_ url: URL) async -> String {
        if store.value(for: url) != nil { return "served from cache" }
        let data = await fetcher.download(url)
        let image = decoder.decode(data)
        store.insert(image, for: url)
        return "downloaded · decoded · cached"
    }
}
