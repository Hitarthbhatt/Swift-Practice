import UIKit

// MARK: - NSCache wrapper
// NSCache is thread-safe and auto-evicts under memory pressure.
// Interview: NSCache vs Dictionary?
//   • NSCache evicts automatically (OS pressure) — Dictionary does not
//   • NSCache is thread-safe — Dictionary is not
//   • NSCache doesn't copy keys (uses object identity) — use NSURL not URL
//   • countLimit + totalCostLimit give eviction hints (not hard caps)

final actor ImageCacheStore {
    private let cache = NSCache<NSURL, UIImage>()

    init(countLimit: Int = 100, costLimit: Int = 50 * 1024 * 1024) {
        cache.countLimit = countLimit
        cache.totalCostLimit = costLimit   // 50 MB default
    }

    func get(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func set(_ image: UIImage, for url: URL) {
        // Cost = raw pixel bytes — gives memory pressure system accurate info
        let cost = Int(image.size.width * image.size.height * image.scale * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    func clear() { cache.removeAllObjects() }
}
