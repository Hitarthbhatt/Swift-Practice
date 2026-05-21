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
// Public sample MP4s (test-videos.co.uk) — each quality is a real re-encode of
// the same clip at that resolution, so the picker maps to genuine bitrates.

extension VideoDownloadViewModel {
    static let catalog: [VideoItem] = {
        // .../vids/<clip>/mp4/h264/<res>/<File>_<res>_10s_<size>MB.mp4
        func item(_ id: String, _ title: String, _ clip: String, _ file: String) -> VideoItem {
            func url(_ res: String, _ size: String) -> URL {
                URL(string: "https://test-videos.co.uk/vids/\(clip)/mp4/h264/\(res)/\(file)_\(res)_10s_\(size)MB.mp4")!
            }
            return VideoItem(id: id, title: title, variants: [
                VideoVariant(quality: .low,    url: url("360", "1")),
                VideoVariant(quality: .medium, url: url("720", "2")),
                VideoVariant(quality: .high,   url: url("1080", "5")),
            ])
        }
        return [
            item("bbb", "Big Buck Bunny", "bigbuckbunny", "Big_Buck_Bunny"),
            item("jellyfish", "Jellyfish", "jellyfish", "Jellyfish"),
            item("sintel", "Sintel", "sintel", "Sintel"),
        ]
    }()
}
