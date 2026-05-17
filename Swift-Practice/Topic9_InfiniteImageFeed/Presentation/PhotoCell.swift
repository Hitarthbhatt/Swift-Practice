import UIKit

// MARK: - Presentation: PhotoCell
//
// A UICollectionViewCell that loads its image via Topic 7's ImageLoader.
//
// Key responsibilities (all performance/correctness critical):
//   1. Cancel the in-flight load in `prepareForReuse` — otherwise a
//      stale download can complete and stomp the next cell's image.
//   2. "Wrong image" guard — after `await`, verify the cell still
//      belongs to the URL we started loading before assigning the image.
//   3. Never retain a Task across reuse — always null it out.
//
// Because UICollectionViewCell is @MainActor in strict concurrency,
// the `Task { ... }` created inside `configure` inherits main-actor
// isolation — so setting `imageView.image` after the await is safe.
final class PhotoCell: UICollectionViewCell {
    static let reuseID = "PhotoCell"

    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var loadTask: Task<Void, Never>?
    private var currentURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 6
        contentView.clipsToBounds = true

        imageView.frame = contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with url: URL) {
        currentURL = url
        imageView.image = nil
        spinner.startAnimating()

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let image = try await ImageLoader.shared.load(url: url)
                // "Wrong image" guard — by the time this line runs, the
                // cell may have been dequeued for a different index path.
                // Without this check you get the classic scroll-flicker
                // bug where thumbnails briefly flash the wrong image.
                guard self.currentURL == url else { return }
                self.imageView.image = image
                self.spinner.stopAnimating()
            } catch {
                if self.currentURL == url {
                    self.spinner.stopAnimating()
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        currentURL = nil
        imageView.image = nil
        spinner.stopAnimating()
    }
}
