import Foundation

// MARK: - HLS quality / bitrate selection

enum HLSQuality: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "Max"

    var id: String { rawValue }

    /// `AVAssetDownloadTaskMinimumRequiredMediaBitrateKey` — AVFoundation picks the
    /// smallest variant whose peak bitrate is >= this. nil/high = best available.
    var minimumBitrate: Int? {
        switch self {
        case .low:    return 300_000
        case .medium: return 1_500_000
        case .high:   return nil
        }
    }
}

struct HLSAsset: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL          // master .m3u8
}

enum HLSStatus: String, Codable {
    case notStarted
    case downloading
    case paused
    case completed
    case failed
}

/// Persisted (UserDefaults JSON). `relativePath` is stored relative to the home
/// dir — the app container path changes between launches, so the absolute URL
/// must be rebuilt from NSHomeDirectory() each time.
struct HLSRecord: Codable {
    var assetID: String
    var quality: HLSQuality
    var status: HLSStatus
    var percent: Double = 0
    var relativePath: String?

    /// Rebuilt offline asset location, valid for the current launch.
    var localURL: URL? {
        guard let relativePath else { return nil }
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(relativePath)
    }
}
