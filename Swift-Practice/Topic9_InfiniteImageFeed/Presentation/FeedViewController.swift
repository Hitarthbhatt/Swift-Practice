import UIKit

// MARK: - Presentation: FeedViewController
//
// Topic 9 (Performance & Optimization) in one screen:
//
//   1. UICollectionViewCompositionalLayout
//      Declarative item → group → section layout. Scales better than
//      UICollectionViewFlowLayout and keeps layout math out of the
//      view controller. We use a fixed 3-column square grid here.
//
//   2. UICollectionViewDiffableDataSource
//      Instead of calling `reloadData()` (which invalidates every cell)
//      or juggling `insertItems(at:)` + index-path math (which throws
//      if the numbers don't match), we build an NSDiffableDataSourceSnapshot
//      of the desired state and let UIKit diff it against the previous
//      snapshot. Only the actually-changed cells animate in.
//
//   3. UICollectionViewDataSourcePrefetching
//      Two jobs:
//        a) warm Topic 7's ImageLoader cache for cells about to scroll
//           into view, so the user never sees a spinner; and
//        b) trigger the next page fetch when the user is within ~10
//           cells of the end, producing smooth infinite scrolling.
//
// Combined with Topic 7's actor-based, dedup-aware, NSCache-backed
// ImageLoader and Topic 8's ExponentialBackoff retry, we get a grid
// that's smooth, resilient, and framework-idiomatic.
final class FeedViewController: UICollectionViewController {

    // Section identifier: Int (not a custom enum).
    //
    // This project builds with `-default-isolation=MainActor`, which
    // makes user-declared types implicitly @MainActor — including a
    // nested or file-scope `enum Section { case main }`. That in turn
    // makes their synthesized `Hashable` conformance main-actor-isolated,
    // and `UICollectionViewDiffableDataSource` requires its section and
    // item identifiers to be `Sendable`. Using `Int` sidesteps the
    // isolation maze entirely — it's trivially Hashable + Sendable +
    // nonisolated. We use `0` as the only section.
    private typealias DataSource = UICollectionViewDiffableDataSource<Int, Photo>
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Int, Photo>

    private var dataSource: DataSource!
    private let viewModel: FeedViewModel

    init(viewModel: FeedViewModel) {
        self.viewModel = viewModel
        super.init(collectionViewLayout: Self.makeLayout())
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Infinite Feed"
        collectionView.backgroundColor = .systemBackground
        collectionView.prefetchDataSource = self
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseID)

        configureDataSource()
        startObserving()
        Task { await viewModel.loadNextPageIfNeeded() }
    }

    // MARK: - Layout: 3-column square grid
    private static func makeLayout() -> UICollectionViewLayout {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(
                widthDimension: .fractionalWidth(1.0 / 3.0),
                heightDimension: .fractionalHeight(1.0)
            )
        )
        item.contentInsets = .init(top: 1, leading: 1, bottom: 1, trailing: 1)

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(
                widthDimension: .fractionalWidth(1.0),
                // Height == 1/3 of the width makes each row a square band
                heightDimension: .fractionalWidth(1.0 / 3.0)
            ),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        return UICollectionViewCompositionalLayout(section: section)
    }

    // MARK: - Diffable Data Source
    //
    // Item type is `Photo` directly (it's Hashable with ID-only equality).
    // The cell provider is the ONLY place that knows how to map a Photo
    // to a concrete UI cell — the VM has no idea cells exist.
    private func configureDataSource() {
        dataSource = DataSource(collectionView: collectionView) {
            (cv: UICollectionView, indexPath: IndexPath, photo: Photo) -> UICollectionViewCell in
            let cell = cv.dequeueReusableCell(
                withReuseIdentifier: PhotoCell.reuseID,
                for: indexPath
            ) as! PhotoCell
            cell.configure(with: photo.thumbnailURL)
            return cell
        }
    }

    // MARK: - @Observable → UIKit bridge
    //
    // SwiftUI auto-subscribes to @Observable properties. UIKit doesn't,
    // so we use the Observation framework's primitive:
    //
    //   `withObservationTracking { read props } onChange: { ... }`
    //
    // `onChange` fires ONCE (when any tracked property is about to change)
    // and then the tracker is gone. To keep receiving updates, we
    // re-register inside `onChange`. And because `onChange` runs
    // synchronously from the mutation's willSet, we defer the snapshot
    // apply + re-registration to the next main-actor tick with a Task.
    private func startObserving() {
        withObservationTracking {
            _ = viewModel.photos.count
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.applySnapshot()
                self?.startObserving()
            }
        }
    }

    private func applySnapshot() {
        var snap = Snapshot()
        snap.appendSections([0])
        snap.appendItems(viewModel.photos, toSection: 0)
        dataSource.apply(snap, animatingDifferences: true)
    }
}

// MARK: - Prefetching

extension FeedViewController: UICollectionViewDataSourcePrefetching {

    func collectionView(
        _ collectionView: UICollectionView,
        prefetchItemsAt indexPaths: [IndexPath]
    ) {
        // 1. Warm the image cache for cells about to appear on screen.
        //    ImageLoader will dedup these against any active loads and
        //    populate its NSCache so the cell's configure(with:) call
        //    returns instantly once the cell is displayed.
        for indexPath in indexPaths where indexPath.item < viewModel.photos.count {
            let url = viewModel.photos[indexPath.item].thumbnailURL
            Task.detached(priority: .utility) {
                _ = try? await ImageLoader.shared.load(url: url)
            }
        }

        // 2. Infinite scroll trigger: when the user prefetches anything
        //    within the last 10 items, kick off the next page. The VM
        //    guards against concurrent calls so this is safe to spam.
        if let maxItem = indexPaths.map(\.item).max(),
           maxItem >= viewModel.photos.count - 10 {
            Task { await viewModel.loadNextPageIfNeeded() }
        }
    }

    // Intentionally NOT implementing `cancelPrefetchingForItemsAt`.
    //
    // Topic 7's ImageLoader dedups in-flight downloads: if a prefetched
    // URL is also requested by a visible cell, they share the same Task.
    // Calling `cancel(url:)` here would also cancel the visible cell's
    // load, producing a broken image. Letting the prefetch finish
    // populates the cache and costs nothing once the request is in flight.
}
