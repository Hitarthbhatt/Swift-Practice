import Foundation

// MARK: - Generic Network Client (async/await)
// Interview: "Design a generic, testable network layer"
//
// Key design decisions:
// - Generic over Decodable response type
// - Protocol-based for testability (mock via protocol)
// - Configurable base URL, decoder, interceptors
// - Automatic retry, token refresh hooks
// - Typed request objects (APIRequest protocol)

protocol AsyncNetworkClientProtocol {
    func send<R: APIRequest>(_ request: R) async throws -> R.Response
}

final class AsyncNetworkClient: AsyncNetworkClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let requestInterceptors: [RequestInterceptor]
    private let responseInterceptors: [ResponseInterceptor]

    init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = .init(),
        requestInterceptors: [RequestInterceptor] = [],
        responseInterceptors: [ResponseInterceptor] = []
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
    }

    func send<R: APIRequest>(_ request: R) async throws -> R.Response {
        var urlRequest = try buildURLRequest(from: request)

        // Apply request interceptors (e.g., auth token, logging)
        for interceptor in requestInterceptors {
            urlRequest = try await interceptor.intercept(urlRequest)
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // Apply response interceptors (e.g., logging, metrics)
        for interceptor in responseInterceptors {
            try await interceptor.intercept(response: httpResponse, data: data)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try decoder.decode(R.Response.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
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

// MARK: - Interceptors (middleware pattern)

protocol RequestInterceptor {
    func intercept(_ request: URLRequest) async throws -> URLRequest
}

protocol ResponseInterceptor {
    func intercept(response: HTTPURLResponse, data: Data) async throws
}

// Auth interceptor — adds Bearer token
struct AuthInterceptor: RequestInterceptor {
    let tokenProvider: () async -> String?

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        if let token = await tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

// Logging interceptor
struct LoggingInterceptor: RequestInterceptor, ResponseInterceptor {
    func intercept(_ request: URLRequest) async throws -> URLRequest {
        print("➡️ \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        return request
    }

    func intercept(response: HTTPURLResponse, data: Data) async throws {
        print("⬅️ \(response.statusCode) (\(data.count) bytes)")
    }
}

// MARK: - Retry wrapper

extension AsyncNetworkClient {
    func sendWithRetry<R: APIRequest>(
        _ request: R,
        maxRetries: Int = 3,
        delay: TimeInterval = 1.0
    ) async throws -> R.Response {2
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                return try await send(request)
            } catch let error as NetworkError {
                lastError = error
                // Only retry on server errors
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
