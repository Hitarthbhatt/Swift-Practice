import Observation
import AVFoundation

@Observable
final class HLSDownloadViewModel {
    let assets: [HLSAsset] = HLSDownloadViewModel.catalog

    private let manager = HLSDownloadManager.shared
    var records: [String: HLSRecord] = [:]
    var selectedQuality: [String: HLSQuality] = [:]

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

    func quality(for asset: HLSAsset) -> HLSQuality {
        selectedQuality[asset.id] ?? records[asset.id]?.quality ?? .medium
    }

    func setQuality(_ quality: HLSQuality, for asset: HLSAsset) {
        selectedQuality[asset.id] = quality
    }

    func status(for asset: HLSAsset) -> HLSStatus {
        records[asset.id]?.status ?? .notStarted
    }

    func percent(for asset: HLSAsset) -> Double {
        records[asset.id]?.percent ?? 0
    }

    func start(_ asset: HLSAsset)  { manager.start(asset, quality: quality(for: asset)) }
    func pause(_ asset: HLSAsset)  { manager.pause(asset.id) }
    func resume(_ asset: HLSAsset) { manager.resume(asset.id) }

    func remove(_ asset: HLSAsset) {
        if playingID == asset.id { stopPlayback() }
        manager.remove(asset.id)
    }

    func play(_ asset: HLSAsset) {
        guard let urlAsset = manager.localAsset(for: asset.id) else { return }
        player.replaceCurrentItem(with: AVPlayerItem(asset: urlAsset))
        player.play()
        playingID = asset.id
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

// MARK: - Demo catalog (Apple public HLS test streams)

extension HLSDownloadViewModel {
    static let catalog: [HLSAsset] = [
        HLSAsset(
            id: "bipbop_adv",
            title: "BipBop Advanced",
            url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!
        ),
        HLSAsset(
            id: "bipbop_16x9",
            title: "BipBop 16x9",
            url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")!
        ),
        HLSAsset(
            id: "bipbop_4x3",
            title: "BipBop 4x3",
            url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")!
        ),
    ]
}
