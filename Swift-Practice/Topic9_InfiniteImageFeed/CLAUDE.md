# Topic 9 — Infinite Image Feed (Performance)

Clean Architecture: Domain → Data → Presentation. UIKit (UICollectionView) for perf.

## Layout
```
Domain/        protocols + entities
Data/          repository implementations
Presentation/  ViewController + Cell + ViewModel
```

## Files
### Domain (pure, no UIKit/Foundation deps beyond stdlib)
- `Photo.swift` — entity.
- `FeedRepository.swift` — protocol.
- `FetchFeedUseCase.swift` — use case wrapping repo.

### Data
- `PicsumFeedRepository.swift` — Picsum.photos impl of `FeedRepository`.

### Presentation
- `FeedViewModel.swift` — `@Observable`. Owns page state, prefetch trigger.
- `FeedViewController.swift` — `UICollectionViewCompositionalLayout` + `UICollectionViewDiffableDataSource` + `UICollectionViewDataSourcePrefetching`.
- `PhotoCell.swift` — async image load, cancel on reuse.

### Entry
- `InfiniteFeedDemoView.swift` — SwiftUI host via `UIViewControllerRepresentable`.

## Perf rules
- Diffable DS, no `reloadData`.
- Prefetch N pages ahead via `prefetchItemsAt`.
- Cancel image load in `prepareForReuse`.
