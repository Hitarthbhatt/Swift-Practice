import AVFoundation

// MARK: - HLSDownloadManager (AVAssetDownloadURLSession)
//
// The "proper" way to download streaming video on iOS. AVFoundation manages a
// local FairPlay-style asset bundle; playback is offline via AVURLAsset.
//
// Feature map:
//   - Pause / Resume → AVAssetDownloadTask.suspend() / .resume()
//   - Background     → background URLSessionConfiguration, OS continues
//   - Survive kill   → records (UserDefaults) + getAllTasks() re-association,
//                      plus relativePath so the offline bundle is re-locatable
//   - Progress       → didLoad timeRange delegate (fraction of total duration)
//   - Quality        → AVAssetDownloadTaskMinimumRequiredMediaBitrateKey
//
// delegateQueue = .main; delegate methods are nonisolated and hop via
// MainActor.assumeIsolated.

final class HLSDownloadManager: NSObject {
    static let shared = HLSDownloadManager()

    private(set) var records: [String: HLSRecord] = [:]
    private var tasks: [String: AVAssetDownloadTask] = [:]

    var onChange: (() -> Void)?
    var backgroundCompletion: (() -> Void)?

    static let backgroundIdentifier = "com.swiftpractice.hlsdownload"
    private let defaultsKey = "hls.records"

    private lazy var session: AVAssetDownloadURLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.backgroundIdentifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false   // download now, don't wait for "optimal" conditions
        return AVAssetDownloadURLSession(
            configuration: config,
            assetDownloadDelegate: self,
            delegateQueue: .main
        )
    }()

    private override init() {
        super.init()
        loadRecords()
        reattach()
    }

    // MARK: Persistence (small enough for UserDefaults)

    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let recs = try? JSONDecoder().decode([String: HLSRecord].self, from: data)
        else { return }
        records = recs
    }

    private func saveRecords() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func reattach() {
        session.getAllTasks { sessionTasks in
            MainActor.assumeIsolated {
                for case let task as AVAssetDownloadTask in sessionTasks {
                    guard let id = task.taskDescription else { continue }
                    self.tasks[id] = task
                    // Only mark live tasks downloading. Never resurrect paused /
                    // completed records — a recovered task that's still around for
                    // a paused record gets re-cancelled below.
                    switch self.records[id]?.status {
                    case .completed:
                        break
                    case .paused:
                        task.cancel()
                        self.tasks[id] = nil
                    default:
                        self.records[id]?.status = .downloading
                    }
                }
                self.onChange?()
            }
        }
    }

    // MARK: Public API

    func record(for assetID: String) -> HLSRecord? { records[assetID] }

    func start(_ asset: HLSAsset, quality: HLSQuality) {
        if records[asset.id]?.status == .downloading { return }
        records[asset.id] = HLSRecord(
            assetID: asset.id,
            sourceURL: asset.url,
            title: asset.title,
            quality: quality,
            status: .downloading
        )
        spawnTask(for: asset.id)
        saveRecords()
        onChange?()
    }

    // Pause = cancel. AVAssetDownloadTask.suspend() is NOT honored across app
    // termination — the background daemon keeps downloading while the app is
    // dead. Cancelling truly stops it; the partial bundle stays on disk so
    // resume continues from there.
    func pause(_ assetID: String) {
        tasks[assetID]?.cancel()
        tasks[assetID] = nil
        records[assetID]?.status = .paused
        saveRecords()
        onChange?()
    }

    func resume(_ assetID: String) {
        guard records[assetID] != nil else { return }
        records[assetID]?.status = .downloading
        spawnTask(for: assetID)   // new task continues from the retained partial
        saveRecords()
        onChange?()
    }

    /// Create + start an AVAssetDownloadTask from the persisted record.
    private func spawnTask(for assetID: String) {
        guard let rec = records[assetID] else { return }
        let urlAsset = AVURLAsset(url: rec.sourceURL)
        var options: [String: Any] = [:]
        if let bitrate = rec.quality.minimumBitrate {
            options[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = bitrate
        }
        guard let task = session.makeAssetDownloadTask(
            asset: urlAsset,
            assetTitle: rec.title,
            assetArtworkData: nil,
            options: options
        ) else { return }
        task.taskDescription = assetID
        tasks[assetID] = task
        task.resume()
    }

    func remove(_ assetID: String) {
        tasks[assetID]?.cancel()
        tasks[assetID] = nil
        if let url = records[assetID]?.localURL {
            try? FileManager.default.removeItem(at: url)
        }
        records[assetID] = nil
        saveRecords()
        onChange?()
    }

    func localAsset(for assetID: String) -> AVURLAsset? {
        guard let url = records[assetID]?.localURL else { return nil }
        return AVURLAsset(url: url)
    }
}

// MARK: - AVAssetDownloadDelegate

extension HLSDownloadManager: AVAssetDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didLoad timeRange: CMTimeRange,
        totalTimeRangesLoaded loadedTimeRanges: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange
    ) {
        MainActor.assumeIsolated {
            guard let id = assetDownloadTask.taskDescription else { return }
            let expected = timeRangeExpectedToLoad.duration.seconds
            guard expected > 0 else { return }
            let loaded = loadedTimeRanges.reduce(0.0) { $0 + $1.timeRangeValue.duration.seconds }
            records[id]?.percent = min(1, loaded / expected)
            onChange?()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Store relative path — container path changes between launches.
        MainActor.assumeIsolated {
            guard let id = assetDownloadTask.taskDescription else { return }
            records[id]?.relativePath = location.relativePath
            records[id]?.status = .completed
            records[id]?.percent = 1
            saveRecords()
            onChange?()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        MainActor.assumeIsolated {
            guard let id = task.taskDescription else { return }
            if let error, (error as NSError).code != NSURLErrorCancelled {
                if records[id]?.status != .completed {
                    records[id]?.status = .failed
                }
            }
            tasks[id] = nil
            saveRecords()
            onChange?()
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        MainActor.assumeIsolated {
            backgroundCompletion?()
            backgroundCompletion = nil
        }
    }
}
