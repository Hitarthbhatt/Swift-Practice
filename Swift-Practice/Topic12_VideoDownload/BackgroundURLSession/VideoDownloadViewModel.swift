import Observation
import AVFoundation

@Observable
final class VideoDownloadViewModel {
    let videos: [VideoItem] = VideoDownloadViewModel.catalog

    private let manager = VideoDownloadManager.shared
    var records: [String: DownloadRecord] = [:]
    var selectedQuality: [String: VideoQuality] = [:]

    // Playback of completed files.
    let player = AVPlayer()
    var playingID: String?
    var isPlaying = false

    init() {
        records = manager.records
        manager.onChange = { [weak self] in
            guard let self else { return }
            self.records = self.manager.records
        }
    }

    // MARK: Quality

    func quality(for video: VideoItem) -> VideoQuality {
        selectedQuality[video.id] ?? records[video.id]?.quality ?? .medium
    }

    func setQuality(_ quality: VideoQuality, for video: VideoItem) {
        selectedQuality[video.id] = quality
    }

    // MARK: Download controls

    func status(for video: VideoItem) -> DownloadStatus {
        records[video.id]?.status ?? .notStarted
    }

    func progress(for video: VideoItem) -> Double {
        records[video.id]?.progress ?? 0
    }

    func start(_ video: VideoItem)  { manager.start(video, quality: quality(for: video)) }
    func pause(_ video: VideoItem)  { manager.pause(video.id) }
    func resume(_ video: VideoItem) { manager.resume(video.id) }

    func remove(_ video: VideoItem) {
        if playingID == video.id { stopPlayback() }
        manager.remove(video.id)
    }

    // MARK: Playback

    func play(_ video: VideoItem) {
        guard let url = manager.completedFileURL(for: video.id) else { return }
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
        playingID = video.id
        isPlaying = true
    }

    func togglePlay() {
        guard playingID != nil else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    private func stopPlayback() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        playingID = nil
        isPlaying = false
    }
}

// MARK: - Demo catalog
// Public sample MP4s used as stand-in "quality variants" (different files of
// increasing size). In production each variant is the same content re-encoded.

extension VideoDownloadViewModel {
    static let catalog: [VideoItem] = {
        let bucket = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample"
        func item(_ id: String, _ title: String, _ low: String, _ med: String, _ high: String) -> VideoItem {
            VideoItem(id: id, title: title, variants: [
                VideoVariant(quality: .low,    url: URL(string: "\(bucket)/\(low)")!),
                VideoVariant(quality: .medium, url: URL(string: "\(bucket)/\(med)")!),
                VideoVariant(quality: .high,   url: URL(string: "\(bucket)/\(high)")!),
            ])
        }
        return [
            item("bbb", "Big Buck Bunny", "ForBiggerEscapes.mp4", "ForBiggerFun.mp4", "BigBuckBunny.mp4"),
            item("elephant", "Elephants Dream", "ForBiggerBlazes.mp4", "ForBiggerJoyrides.mp4", "ElephantsDream.mp4"),
            item("sintel", "Sintel Teaser", "ForBiggerMeltdowns.mp4", "TearsOfSteel.mp4", "Sintel.mp4"),
        ]
    }()
}
