import SwiftUI
import Combine

// MARK: - Sample API Requests using the generic APIRequest protocol

struct Post: Codable, Identifiable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
}

struct FetchPostsRequest: APIRequest {
    typealias Response = [Post]
    var path: String { "/posts" }
    var queryItems: [URLQueryItem]? {
        [URLQueryItem(name: "_limit", value: "\(limit)")]
    }
    let limit: Int
}

struct FetchPostRequest: APIRequest {
    typealias Response = Post
    let id: Int
    var path: String { "/posts/\(id)" }
}

struct CreatePostRequest: APIRequest {
    typealias Response = Post
    var path: String { "/posts" }
    var method: HTTPMethod { .post }
    var body: (any Encodable)? { payload }

    struct Payload: Encodable {
        let title: String
        let body: String
        let userId: Int
    }
    let payload: Payload
}

// MARK: - Demo ViewModel

@MainActor
final class NetworkingDemoViewModel: ObservableObject {
    @Published var asyncPosts: [Post] = []
    @Published var combinePosts: [Post] = []
    @Published var log: [String] = []
    @Published var isLoading = false

    private let asyncClient: AsyncNetworkClient
    private let combineClient: CombineNetworkClient
    private var cancellables = Set<AnyCancellable>()

    init() {
        let baseURL = URL(string: "https://jsonplaceholder.typicode.com")!

        asyncClient = AsyncNetworkClient(
            baseURL: baseURL,
            requestInterceptors: [LoggingInterceptor()],
            responseInterceptors: [LoggingInterceptor()]
        )

        combineClient = CombineNetworkClient(baseURL: baseURL)
    }

    // MARK: - async/await fetch
    func fetchPostsAsync() async {
        isLoading = true
        log.append("--- async/await ---")

        do {
            let request = FetchPostsRequest(limit: 5)
            let posts = try await asyncClient.send(request)
            asyncPosts = posts
            log.append("✅ Fetched \(posts.count) posts (async)")
        } catch {
            log.append("❌ \(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Combine fetch
    func fetchPostsCombine() {
        isLoading = true
        log.append("--- Combine ---")

        let request = FetchPostsRequest(limit: 5)
        combineClient.send(request)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.log.append("❌ \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] posts in
                    self?.combinePosts = posts
                    self?.log.append("✅ Fetched \(posts.count) posts (Combine)")
                }
            )
            .store(in: &cancellables)
    }

    // MARK: - POST example (async)
    func createPostAsync() async {
        log.append("--- POST (async) ---")
        do {
            let request = CreatePostRequest(payload: .init(
                title: "Test Post",
                body: "Created from Swift",
                userId: 1
            ))
            let post = try await asyncClient.send(request)
            log.append("✅ Created post id=\(post.id)")
        } catch {
            log.append("❌ \(error.localizedDescription)")
        }
    }
}

// MARK: - View

struct NetworkingDemoView: View {
    @StateObject private var vm = NetworkingDemoViewModel()

    var body: some View {
        List {
            Section("async/await Client") {
                Button("Fetch Posts") { Task { await vm.fetchPostsAsync() } }
                Button("Create Post (POST)") { Task { await vm.createPostAsync() } }
                ForEach(vm.asyncPosts) { post in
                    Text(post.title).font(.caption)
                }
            }

            Section("Combine Client") {
                Button("Fetch Posts") { vm.fetchPostsCombine() }
                ForEach(vm.combinePosts) { post in
                    Text(post.title).font(.caption)
                }
            }

            Section("Log") {
                ForEach(Array(vm.log.enumerated()), id: \.offset) { _, entry in
                    Text(entry).font(.caption.monospaced())
                }
            }
        }
        .navigationTitle("Networking")
        .overlay { if vm.isLoading { ProgressView() } }
    }
}

#Preview {
    NavigationStack { NetworkingDemoView() }
}
