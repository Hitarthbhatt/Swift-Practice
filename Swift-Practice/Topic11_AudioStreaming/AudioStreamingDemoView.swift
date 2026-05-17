import SwiftUI

struct AudioStreamingDemoView: View {
    @State private var vm = AudioPlayerViewModel()
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            header
            scrubber
            transport
            qualityPicker
            trackList
        }
        .padding()
        .navigationTitle("HLS Audio")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(vm.currentTrack?.title ?? "—").font(.title3).bold()
            Text(vm.currentTrack?.artist ?? "").foregroundStyle(.secondary).font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubValue : vm.currentTime },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(vm.duration, 1),
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing { vm.seek(to: scrubValue) }
                }
            )
            HStack {
                Text(format(isScrubbing ? scrubValue : vm.currentTime))
                Spacer()
                Text(format(vm.duration))
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
    }

    private var transport: some View {
        HStack(spacing: 40) {
            Button { vm.previous() } label: {
                Image(systemName: "backward.fill")
            }
            Button { vm.toggle() } label: {
                Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            Button { vm.next() } label: {
                Image(systemName: "forward.fill")
            }
        }
        .font(.title)
        .buttonStyle(.plain)
    }

    private var qualityPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quality (preferredPeakBitRate)").font(.caption).foregroundStyle(.secondary)
            Picker("Quality", selection: $vm.quality) {
                ForEach(AudioQuality.allCases) { q in
                    Text(q.rawValue.capitalized).tag(q)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var trackList: some View {
        List {
            ForEach(vm.tracks.indices, id: \.self) { idx in
                let t = vm.tracks[idx]
                Button {
                    vm.select(index: idx)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(t.title).foregroundStyle(.primary)
                            Text(t.artist).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if idx == vm.currentIndex {
                            Image(systemName: vm.isPlaying ? "waveform" : "speaker.wave.2")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func format(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "00:00" }
        let m = Int(s) / 60
        let sec = Int(s) % 60
        return String(format: "%02d:%02d", m, sec)
    }
}

#Preview {
    NavigationStack { AudioStreamingDemoView() }
}
