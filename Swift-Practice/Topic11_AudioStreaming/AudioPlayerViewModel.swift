import AVFoundation
import Observation

struct AudioTrack: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let artist: String
    let url: URL
}

enum AudioQuality: String, CaseIterable, Identifiable {
    case auto, low, medium, high
    var id: String { rawValue }
    /// 0 = let HLS ABR decide. Otherwise cap variant peak bitrate (bits/sec).
    var preferredPeakBitRate: Double {
        switch self {
        case .auto: return 0
        case .low: return 64_000
        case .medium: return 192_000
        case .high: return 320_000
        }
    }
}

@MainActor
@Observable
final class AudioPlayerViewModel {
    private let player = AVPlayer()
    private var timeObserver: Any?

    var tracks: [AudioTrack] = AudioPlayerViewModel.demoTracks
    var currentIndex: Int = 0
    var isPlaying: Bool = false
    var currentTime: Double = 0
    var duration: Double = 0
    var quality: AudioQuality = .auto {
        didSet { player.currentItem?.preferredPeakBitRate = quality.preferredPeakBitRate }
    }

    var currentTrack: AudioTrack? {
        tracks.indices.contains(currentIndex) ? tracks[currentIndex] : nil
    }

    init() {
        configureSession()
        load()
    }

    func play() {
        if player.currentItem == nil { load() }
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func toggle() { isPlaying ? pause() : play() }

    func next() {
        guard !tracks.isEmpty else { return }
        currentIndex = (currentIndex + 1) % tracks.count
        load()
        play()
    }

    func previous() {
        guard !tracks.isEmpty else { return }
        currentIndex = (currentIndex - 1 + tracks.count) % tracks.count
        load()
        play()
    }

    func select(index: Int) {
        guard tracks.indices.contains(index) else { return }
        currentIndex = index
        load()
        play()
    }

    func seek(to seconds: Double) {
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: target)
        currentTime = seconds
    }

    private func load() {
        guard let track = currentTrack else { return }
        let item = AVPlayerItem(url: track.url)
        item.preferredPeakBitRate = quality.preferredPeakBitRate
        player.replaceCurrentItem(with: item)
        currentTime = 0
        duration = 0
        observeProgress()
        loadDuration(item: item)
    }

    private func observeProgress() {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }
    }

    private func loadDuration(item: AVPlayerItem) {
        Task { [weak self] in
            let d = (try? await item.asset.load(.duration).seconds) ?? 0
            if d.isFinite, d > 0 {
                await MainActor.run { self?.duration = d }
            }
        }
    }

    private func configureSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    static let demoTracks: [AudioTrack] = [
        AudioTrack(
            title: "BipBop (Apple HLS)",
            artist: "Apple Sample",
            url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!
        ),
        AudioTrack(
            title: "BipBop 16x9 Variant",
            artist: "Apple Sample",
            url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")!
        ),
        AudioTrack(
            title: "Basic 4x3 Stream",
            artist: "Apple Sample",
            url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")!
        ),
    ]
}
