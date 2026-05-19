import Foundation
import Combine

// MARK: - Generic Network Client (Combine)
// Interview: "How would you build a Combine-based network layer?"
//
// Key differences from async/await version:
// - Returns AnyPublisher<T, NetworkError> instead of async throws -> T
// - Cancellation via AnyCancellable (store in Set)
// - Operators for retry, timeout, mapping
// - Good for: streams, chaining multiple requests, reactive UI binding
//
// When to choose which:
// - async/await: simpler, better for request-response, structured concurrency
// - Combine: better for reactive streams, debounce/throttle, complex pipelines

protocol CombineNetworkClientProtocol {
    func send<R: APIRequest>(_ request: R) -> AnyPublisher<R.Response, NetworkError>
}

final class CombineNetworkClient: CombineNetworkClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let authToken: AnyPublisher<String?, Never>

    init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = .init(),
        authToken: AnyPublisher<String?, Never> = Just(nil).eraseToAnyPublisher()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.authToken = authToken
    }

    func send<R: APIRequest>(_ request: R) -> AnyPublisher<R.Response, NetworkError> {
        // Build URLRequest, then flatMap into data task publisher
        authToken
            .first() // take current token value
            .tryMap { [self] token -> URLRequest in
                try buildURLRequest(from: request, token: token)
            }
            .mapError { NetworkError.unknown($0) }
            .flatMap { [self] urlRequest in
                session.dataTaskPublisher(for: urlRequest)
                    .mapError { NetworkError.unknown($0) }
            }
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
                }
                return data
            }
            .mapError { error in
                (error as? NetworkError) ?? .unknown(error)
            }
            .decode(type: R.Response.self, decoder: decoder)
            .mapError { error in
                if error is DecodingError {
                    return .decodingError(error)
                }
                return (error as? NetworkError) ?? .unknown(error)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Convenience: with retry and timeout
    func sendWithRetry<R: APIRequest>(
        _ request: R,
        retries: Int = 3,
        timeout: TimeInterval = 30
    ) -> AnyPublisher<R.Response, NetworkError> {
        send(request)
            .timeout(.seconds(timeout), scheduler: DispatchQueue.global(), customError: { .unknown(URLError(.timedOut)) })
            .retry(retries)
            .eraseToAnyPublisher()
    }

    private func buildURLRequest<R: APIRequest>(from request: R, token: String?) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: true)
        components?.queryItems = request.queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.headers?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let body = request.body {
            urlRequest.httpBody = try JSONEncoder().encode(body)
        }

        return urlRequest
    }
}
