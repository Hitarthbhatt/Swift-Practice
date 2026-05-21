import Foundation

// MARK: - DownloadStore
// Disk persistence so downloads survive app termination:
//   - records.json  → all DownloadRecords (status, bytes, file names)
//   - resume/       → resume-data blobs (one per paused/failed download)
//   - completed/    → finished video files

final class DownloadStore {
    private let fm = FileManager.default
    private let recordsURL: URL
    private let videosDir: URL
    private let resumeDir: URL

    init() {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VideoDownloads", isDirectory: true)
        videosDir  = base.appendingPathComponent("completed", isDirectory: true)
        resumeDir  = base.appendingPathComponent("resume", isDirectory: true)
        recordsURL = base.appendingPathComponent("records.json")
        for dir in [base, videosDir, resumeDir] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: Records

    func loadRecords() -> [String: DownloadRecord] {
        guard let data = try? Data(contentsOf: recordsURL),
              let recs = try? JSONDecoder().decode([String: DownloadRecord].self, from: data)
        else { return [:] }
        return recs
    }

    func saveRecords(_ recs: [String: DownloadRecord]) {
        guard let data = try? JSONEncoder().encode(recs) else { return }
        try? data.write(to: recordsURL, options: .atomic)
    }

    // MARK: Resume data

    @discardableResult
    func saveResumeData(_ data: Data, for videoID: String) -> String {
        let name = "\(videoID).resume"
        try? data.write(to: resumeDir.appendingPathComponent(name), options: .atomic)
        return name
    }

    func resumeData(named name: String) -> Data? {
        try? Data(contentsOf: resumeDir.appendingPathComponent(name))
    }

    func deleteResumeData(named name: String) {
        try? fm.removeItem(at: resumeDir.appendingPathComponent(name))
    }

    // MARK: Completed files

    /// Move the URLSession temp file into permanent storage. Must be called
    /// synchronously inside the delegate callback (temp file is short-lived).
    func moveToCompleted(from tempURL: URL, videoID: String) -> String? {
        let name = "\(videoID).mp4"
        let dest = videosDir.appendingPathComponent(name)
        try? fm.removeItem(at: dest)
        do {
            try fm.moveItem(at: tempURL, to: dest)
            return name
        } catch {
            return nil
        }
    }

    func completedURL(named name: String) -> URL {
        videosDir.appendingPathComponent(name)
    }

    func deleteCompleted(named name: String) {
        try? fm.removeItem(at: completedURL(named: name))
    }
}
