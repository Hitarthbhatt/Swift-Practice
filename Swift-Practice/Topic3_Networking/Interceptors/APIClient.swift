import Foundation

// MARK: - Transport (URLSession in prod, MockTransport in tests/demos)

protocol NetworkTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

// MARK: - API Client (orchestrates the interceptor chain)
//
// Flow per attempt:
//   1. Run adapters in order → mutated request
//   2. Notify observers (willSend)
//   3. Send via transport
//   4. Notify observers (didReceive / didFail)
//   5. On non-2xx or thrown error → ask retriers in order
//   6. First retrier returning non-.doNotRetry wins; loop with new attempt
//
// Retry caps:
//   - Configuration.maxRetries is the global ceiling
//   - Each retrier may apply its own per-policy cap

actor APIClient {
    struct Configuration: Sendable {
        var adapters: [RequestAdapter]
        var retriers: [RequestRetrier]
        var observers: [NetworkEventObserver]
        var maxRetries: Int

        init(
            adapters: [RequestAdapter] = [],
            retriers: [RequestRetrier] = [],
            observers: [NetworkEventObserver] = [],
            maxRetries: Int = 3
        ) {
            self.adapters = adapters
            self.retriers = retriers
            self.observers = observers
            self.maxRetries = maxRetries
        }
    }

    private let transport: NetworkTransport
    private var configuration: Configuration

    init(transport: NetworkTransport, configuration: Configuration = .init()) {
        self.transport = transport
        self.configuration = configuration
    }

    func updateConfiguration(_ configuration: Configuration) {
        self.configuration = configuration
    }

    func send(_ request: URLRequest) async throws -> NetworkResponse {
        try await execute(request, attempt: 1)
    }

    private func execute(_ original: URLRequest, attempt: Int) async throws -> NetworkResponse {
        try Task.checkCancellation()
        if attempt > configuration.maxRetries + 1 {
            throw NetworkError.retryLimitExceeded
        }

        var adapted = original
        for adapter in configuration.adapters {
            adapted = try await adapter.adapt(adapted)
        }

        for observer in configuration.observers {
            await observer.willSend(adapted, attempt: attempt)
        }

        do {
            let (data, http) = try await transport.data(for: adapted)
            let networkResponse = NetworkResponse(request: adapted, response: http, data: data)

            for observer in configuration.observers {
                await observer.didReceive(networkResponse, attempt: attempt)
            }

            if (200..<300).contains(http.statusCode) {
                return networkResponse
            }

            if let next = try await consultRetriers(adapted, response: http, error: nil, attempt: attempt) {
                return try await execute(next, attempt: attempt + 1)
            }
            throw NetworkError.unacceptableStatusCode(http.statusCode)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            for observer in configuration.observers {
                await observer.didFail(adapted, error: error, attempt: attempt)
            }
            if let next = try await consultRetriers(adapted, response: nil, error: error, attempt: attempt) {
                return try await execute(next, attempt: attempt + 1)
            }
            throw error
        }
    }

    private func consultRetriers(
        _ request: URLRequest,
        response: HTTPURLResponse?,
        error: Error?,
        attempt: Int
    ) async throws -> URLRequest? {
        for retrier in configuration.retriers {
            let decision = await retrier.retry(request, for: response, dueTo: error, attempt: attempt)
            switch decision {
            case .doNotRetry:
                continue
            case .retry:
                return request
            case .retryAfter(let delay):
                try await Task.sleep(for: delay)
                return request
            case .retryWith(let replacement):
                return replacement
            }
        }
        return nil
    }
}
