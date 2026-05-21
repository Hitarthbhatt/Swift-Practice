import SwiftUI
import AVKit

struct VideoDownloadDemoView: View {
    @State private var vm = VideoDownloadViewModel()

    var body: some View {
        List {
            if vm.playingID != nil {
                Section("Now Playing") {
                    VideoPlayer(player: vm.player)
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets())
                }
            }

            Section {
                ForEach(vm.videos) { video in
                    VideoRow(vm: vm, video: video)
                }
            } footer: {
                Text("Background URLSession download tasks. Pause produces resume data; resume continues from the saved blob. Kill the app mid-download and relaunch — getAllTasks() re-binds running tasks and records.json restores state.")
            }
        }
        .navigationTitle("Video Download")
    }
}

private struct VideoRow: View {
    @Bindable var vm: VideoDownloadViewModel
    let video: VideoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(video.title).font(.headline)
                Spacer()
                statusBadge
            }

            Picker("Quality", selection: Binding(
                get: { vm.quality(for: video) },
                set: { vm.setQuality($0, for: video) }
            )) {
                ForEach(VideoQuality.allCases) { q in
                    Text("\(q.rawValue) · \(q.approxBitrate / 1_000_000)Mbps").tag(q)
                }
            }
            .pickerStyle(.segmented)
            .disabled(vm.status(for: video) == .downloading)

            if vm.status(for: video) != .notStarted {
                ProgressView(value: vm.progress(for: video))
                Text("\(Int(vm.progress(for: video) * 100))%")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            controls
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var controls: some View {
        HStack(spacing: 12) {
            switch vm.status(for: video) {
            case .notStarted, .failed:
                button("Download", "arrow.down.circle") { vm.start(video) }
            case .downloading:
                button("Pause", "pause.circle") { vm.pause(video) }
            case .paused:
                button("Resume", "play.circle") { vm.resume(video) }
            case .completed:
                button("Play", "play.rectangle.fill") { vm.play(video) }
            }

            if vm.status(for: video) != .notStarted {
                button("Delete", "trash", role: .destructive) { vm.remove(video) }
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
        switch vm.status(for: video) {
        case .notStarted: "—"
        case .downloading: "DOWNLOADING"
        case .paused: "PAUSED"
        case .completed: "READY"
        case .failed: "FAILED"
        }
    }

    private var badgeColor: Color {
        switch vm.status(for: video) {
        case .completed: .green
        case .failed: .red
        case .downloading: .blue
        default: .secondary
        }
    }
}

#Preview {
    NavigationStack { VideoDownloadDemoView() }
}
