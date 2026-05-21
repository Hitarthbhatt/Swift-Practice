import SwiftUI
import AVKit

struct HLSDownloadDemoView: View {
    @State private var vm = HLSDownloadViewModel()

    var body: some View {
        List {
            if vm.playingID != nil {
                Section("Now Playing (offline)") {
                    VideoPlayer(player: vm.player)
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                }
            }

            Section {
                ForEach(vm.assets) { asset in
                    HLSRow(vm: vm, asset: asset)
                }
            } footer: {
                Text("AVAssetDownloadTask downloads HLS streams into an offline bundle. Quality maps to AVAssetDownloadTaskMinimumRequiredMediaBitrateKey. suspend()/resume() pause the task; getAllTasks() recovers it after relaunch. Playback is fully offline via the stored relativePath.")
            }
        }
        .navigationTitle("HLS Download")
    }
}

private struct HLSRow: View {
    @Bindable var vm: HLSDownloadViewModel
    let asset: HLSAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(asset.title).font(.headline)
                Spacer()
                statusBadge
            }

            Picker("Quality", selection: Binding(
                get: { vm.quality(for: asset) },
                set: { vm.setQuality($0, for: asset) }
            )) {
                ForEach(HLSQuality.allCases) { q in
                    Text(q.rawValue).tag(q)
                }
            }
            .pickerStyle(.segmented)
            .disabled(vm.status(for: asset) == .downloading)

            if vm.status(for: asset) != .notStarted {
                ProgressView(value: vm.percent(for: asset))
                Text("\(Int(vm.percent(for: asset) * 100))%")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            controls
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var controls: some View {
        HStack(spacing: 12) {
            switch vm.status(for: asset) {
            case .notStarted, .failed:
                button("Download", "arrow.down.circle") { vm.start(asset) }
            case .downloading:
                button("Pause", "pause.circle") { vm.pause(asset) }
            case .paused:
                button("Resume", "play.circle") { vm.resume(asset) }
            case .completed:
                button("Play", "play.rectangle.fill") { vm.play(asset) }
            }

            if vm.status(for: asset) != .notStarted {
                button("Delete", "trash", role: .destructive) { vm.remove(asset) }
            }
        }
        .buttonStyle(.bordered)
        .font(.caption)
    }

    private func button(_ title: String, _ icon: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: icon)
        }
    }

    private var statusBadge: some View {
        Text(badgeText)
            .font(.caption2.bold())
            .foregroundStyle(badgeColor)
    }

    private var badgeText: String {
        switch vm.status(for: asset) {
        case .notStarted: "—"
        case .downloading: "DOWNLOADING"
        case .paused: "PAUSED"
        case .completed: "READY"
        case .failed: "FAILED"
        }
    }

    private var badgeColor: Color {
        switch vm.status(for: asset) {
        case .completed: .green
        case .failed: .red
        case .downloading: .blue
        default: .secondary
        }
    }
}

#Preview {
    NavigationStack { HLSDownloadDemoView() }
}
