import Foundation

// MARK: - Quality / bitrate

enum VideoQuality: String, Codable, CaseIterable, Identifiable {
    case low = "360p"
    case medium = "720p"
    case high = "1080p"

    var id: String { rawValue }

    /// Approx encode bitrate for display (bits/sec).
    var approxBitrate: Int {
        switch self {
        case .low:    return 1_000_000
        case .medium: return 2_500_000
        case .high:   return 5_000_000
        }
    }
}

struct VideoVariant: Hashable {
    let quality: VideoQuality
    let url: URL
}

struct VideoItem: Identifiable, Hashable {
    let id: String
    let title: String
    let variants: [VideoVariant]

    func variant(_ quality: VideoQuality) -> VideoVariant? {
        variants.first { $0.quality == quality }
    }
}

// MARK: - Persisted download state

enum DownloadStatus: String, Codable {
    case notStarted
    case downloading
    case paused
    case completed
    case failed
}

/// Survives app kill — persisted to disk by `DownloadStore`. `taskDescription`
/// on the URLSession task carries `videoID` so we can re-associate on relaunch.
struct DownloadRecord: Codable {
    var videoID: String
    var sourceURL: URL
    var quality: VideoQuality
    var status: DownloadStatus
    var bytesWritten: Int64 = 0
    var totalBytes: Int64 = 0
    var localFileName: String?       // completed file in Application Support
    var resumeDataFileName: String?  // saved resume-data blob (pause / failure)

    var progress: Double {
        totalBytes > 0 ? min(1, Double(bytesWritten) / Double(totalBytes)) : 0
    }
}
