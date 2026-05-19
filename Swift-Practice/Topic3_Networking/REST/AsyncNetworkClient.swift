import Foundation

// MARK: - Generic Network Client (async/await)
//
// Generic over Decodable response. Adapters mutate the request, observers tap
// lifecycle events read-only. Shares its interceptor protocols with the actor-
// based `APIClient` in this same topic so both clients build on one model.

protocol AsyncNetworkClientProtocol {
    func send<R: APIRequest>(_ request: R) async throws -> R.Response
}

final class AsyncNetworkClient: AsyncNetworkClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let adapters: [RequestAdapter]
    private let observers: [NetworkEventObserver]

    init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = .init(),
        adapters: [RequestAdapter] = [],
        observers: [NetworkEventObserver] = []
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.adapters = adapters
        self.observers = observers
    }

    func send<R: APIRequest>(_ request: R) async throws -> R.Response {
        var urlRequest = try buildURLRequest(from: request)

        for adapter in adapters {
            urlRequest = try await adapter.adapt(urlRequest)
        }

        for observer in observers {
            await observer.willSend(urlRequest, attempt: 1)
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            let networkResponse = NetworkResponse(
                request: urlRequest,
                response: httpResponse,
                data: data
            )
            for observer in observers {
                await observer.didReceive(networkResponse, attempt: 1)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
            }

            do {
                return try decoder.decode(R.Response.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        } catch {
            for observer in observers {
                await observer.didFail(urlRequest, error: error, attempt: 1)
            }
            throw error
        }
    }

    private func buildURLRequest<R: APIRequest>(from request: R) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: true)
        components?.queryItems = request.queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.headers?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let body = request.body {
            urlRequest.httpBody = try JSONEncoder().encode(body)
        }

        return urlRequest
    }
}

// MARK: - Retry wrapper

extension AsyncNetworkClient {
    func sendWithRetry<R: APIRequest>(
        _ request: R,
        maxRetries: Int = 3,
        delay: TimeInterval = 1.0
    ) async throws -> R.Response {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                return try await send(request)
            } catch let error as NetworkError {
                lastError = error
                if case .httpError(let code, _) = error, (500...599).contains(code) {
                    let backoff = delay * pow(2, Double(attempt))
                    try await Task.sleep(for: .seconds(backoff))
                    continue
                }
                throw error
            }
        }

        throw lastError ?? NetworkError.unknown(NSError(domain: "", code: -1))
    }
}
