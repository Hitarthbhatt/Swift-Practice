import Foundation

// MARK: - VideoDownloadManager (background URLSession)
//
// One background URLSession, shared singleton (never create two with the same
// identifier — that crashes). Concurrent downloads via multiple download tasks.
//
// Feature map:
//   - Pause          → cancel(byProducingResumeData:) + persist resume blob
//   - Resume         → downloadTask(withResumeData:) or restart from sourceURL
//   - Background     → URLSessionConfiguration.background, OS keeps downloading
//   - Survive kill   → records.json on disk + getAllTasks() re-association
//   - Progress       → didWriteData delegate
//   - Quality        → each VideoItem exposes per-quality variant URLs
//
// delegateQueue = .main so every callback lands on the main thread; the class is
// MainActor-isolated by default (project setting), delegate methods are marked
// `nonisolated` and hop back via MainActor.assumeIsolated (safe — queue is main).

final class VideoDownloadManager: NSObject {
    static let shared = VideoDownloadManager()

    private let store = DownloadStore()
    private(set) var records: [String: DownloadRecord] = [:]
    private var tasks: [String: URLSessionDownloadTask] = [:]   // videoID → task

    /// VM subscribes to re-read `records` whenever anything changes.
    var onChange: (() -> Void)?
    /// Set by AppDelegate; fired once background events finish flushing.
    var backgroundCompletion: (() -> Void)?

    static let backgroundIdentifier = "com.swiftpractice.videodownload"

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: Self.backgroundIdentifier)
        config.sessionSendsLaunchEvents = true   // relaunch app to deliver events
        config.isDiscretionary = false           // start ASAP, don't wait for ideal conditions
        config.allowsCellularAccess = true
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    private override init() {
        super.init()
        records = store.loadRecords()
        reattach()
    }

    // MARK: Re-association after relaunch

    /// The OS keeps background tasks alive across app death. On launch, recover
    /// running tasks and rebind them to records via taskDescription (= videoID).
    private func reattach() {
        session.getAllTasks { sessionTasks in
            MainActor.assumeIsolated {
                for task in sessionTasks {
                    guard let videoID = task.taskDescription,
                          let download = task as? URLSessionDownloadTask else { continue }
                    self.tasks[videoID] = download
                    if self.records[videoID]?.status != .completed {
                        self.records[videoID]?.status = .downloading
                    }
                }
                self.onChange?()
            }
        }
    }

    // MARK: Public API

    func record(for videoID: String) -> DownloadRecord? { records[videoID] }

    func start(_ video: VideoItem, quality: VideoQuality) {
        guard let variant = video.variant(quality) else { return }
        if records[video.id]?.status == .downloading { return }

        var rec = DownloadRecord(
            videoID: video.id,
            sourceURL: variant.url,
            quality: quality,
            status: .downloading
        )
        rec.localFileName = nil
        records[video.id] = rec

        let task = session.downloadTask(with: variant.url)
        task.taskDescription = video.id
        tasks[video.id] = task
        task.resume()

        store.saveRecords(records)
        onChange?()
    }

    func pause(_ videoID: String) {
        guard let task = tasks[videoID] else { return }
        task.cancel(byProducingResumeData: { data in
            MainActor.assumeIsolated {
                if let data {
                    self.records[videoID]?.resumeDataFileName =
                        self.store.saveResumeData(data, for: videoID)
                }
                self.records[videoID]?.status = .paused
                self.tasks[videoID] = nil
                self.store.saveRecords(self.records)
                self.onChange?()
            }
        })
    }

    func resume(_ videoID: String) {
        guard var rec = records[videoID] else { return }

        let task: URLSessionDownloadTask
        if let name = rec.resumeDataFileName, let data = store.resumeData(named: name) {
            task = session.downloadTask(withResumeData: data)
            store.deleteResumeData(named: name)
            rec.resumeDataFileName = nil
        } else {
            // No resume blob (e.g. relaunch after kill with stale state) → restart.
            task = session.downloadTask(with: rec.sourceURL)
        }

        rec.status = .downloading
        records[videoID] = rec
        task.taskDescription = videoID
        tasks[videoID] = task
        task.resume()

        store.saveRecords(records)
        onChange?()
    }

    func remove(_ videoID: String) {
        tasks[videoID]?.cancel()
        tasks[videoID] = nil
        if let name = records[videoID]?.resumeDataFileName { store.deleteResumeData(named: name) }
        if let file = records[videoID]?.localFileName { store.deleteCompleted(named: file) }
        records[videoID] = nil
        store.saveRecords(records)
        onChange?()
    }

    func completedFileURL(for videoID: String) -> URL? {
        guard let name = records[videoID]?.localFileName else { return nil }
        return store.completedURL(named: name)
    }
}

// MARK: - URLSessionDownloadDelegate

extension VideoDownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        MainActor.assumeIsolated {
            guard let videoID = downloadTask.taskDescription else { return }
            records[videoID]?.bytesWritten = totalBytesWritten
            records[videoID]?.totalBytes = totalBytesExpectedToWrite
            onChange?()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Synchronous — temp file at `location` is deleted when this returns.
        MainActor.assumeIsolated {
            guard let videoID = downloadTask.taskDescription else { return }

            // A finished download is not a successful one — a 403/404 body still
            // "finishes". Reject non-2xx so we never save an error page as video.
            if let http = downloadTask.response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                records[videoID]?.status = .failed
                tasks[videoID] = nil
                store.saveRecords(records)
                onChange?()
                return
            }

            if let name = store.moveToCompleted(from: location, videoID: videoID) {
                records[videoID]?.localFileName = name
                records[videoID]?.status = .completed
                if let total = records[videoID]?.totalBytes {
                    records[videoID]?.bytesWritten = total
                }
            } else {
                records[videoID]?.status = .failed
            }
            tasks[videoID] = nil
            store.saveRecords(records)
            onChange?()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        MainActor.assumeIsolated {
            guard let videoID = task.taskDescription else { return }
            if let error {
                let resume = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                if let resume {
                    records[videoID]?.resumeDataFileName = store.saveResumeData(resume, for: videoID)
                    records[videoID]?.status = .paused
                } else if records[videoID]?.status != .completed {
                    records[videoID]?.status = .failed
                }
                tasks[videoID] = nil
                store.saveRecords(records)
                onChange?()
            }
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        MainActor.assumeIsolated {
            backgroundCompletion?()
            backgroundCompletion = nil
        }
    }
}
