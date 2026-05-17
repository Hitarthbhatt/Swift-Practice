import SwiftUI

struct ImageLoaderDemoView: View {
    @State private var vm = ImageLoaderViewModel()

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 8)]

    var body: some View {
        ScrollView {
            // Status bar
            HStack(spacing: 20) {
                counterBadge("Downloading", vm.activeDownloads, .blue)
                counterBadge("Waiting",     vm.waitingCount,    .orange)
                counterBadge("Slot limit",  4,                  .green)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Controls
            HStack(spacing: 10) {
                Button("Load All") { vm.loadAll() }
                    .buttonStyle(.borderedProminent)
                Button("Cancel All", role: .destructive) { vm.cancelAll() }
                    .buttonStyle(.bordered)
                Button("Clear Cache") { vm.clearCache() }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            // Image grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(vm.urls, id: \.self) { url in
                    ImageCell(url: url, state: vm.states[url] ?? .idle) {
                        vm.load(url)
                    } onCancel: {
                        vm.cancel(url)
                    } onReload: {
                        vm.reload(url)
                    }
                }
            }
            .padding(8)
        }
        .navigationTitle("Image Loader")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func counterBadge(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Image Cell

private struct ImageCell: View {
    let url: URL
    let state: ImageState
    let onLoad: () -> Void
    let onCancel: () -> Void
    let onReload: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))

            switch state {
            case .idle:
                Button { onLoad() } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.title2)
                        Text("Tap to load")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }

            case .loading:
                VStack(spacing: 8) {
                    ProgressView().tint(.blue)
                    Text("Loading…").font(.caption2).foregroundStyle(.secondary)
                    Button("Cancel", role: .destructive) { onCancel() }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }

            case .loaded(let image):
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .padding(4)
                }

            case .failed:
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
                    Text("Failed").font(.caption2).foregroundStyle(.red)
                    Button("Retry") { onReload() }.font(.caption2).buttonStyle(.bordered).controlSize(.mini)
                }

            case .cancelled:
                VStack(spacing: 4) {
                    Image(systemName: "xmark.circle").foregroundStyle(.orange)
                    Text("Cancelled").font(.caption2).foregroundStyle(.orange)
                    Button("Reload") { onReload() }.font(.caption2).buttonStyle(.bordered).controlSize(.mini)
                }
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack { ImageLoaderDemoView() }
}
