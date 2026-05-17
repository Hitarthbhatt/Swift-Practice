# Topic 3 — Networking (REST)

Generic, testable network layer with two paradigms.

## Files
- `NetworkError.swift` — typed error enum (transport, decoding, status).
- `AsyncNetworkClient.swift` — async/await client, `APIRequest` protocol, generic `send<R>`.
- `CombineNetworkClient.swift` — same surface, Combine `AnyPublisher`.
- `NetworkingDemoView.swift` — UI calling both clients.

## Pattern
Protocol-based for mocking. Generic over `APIRequest.Response: Decodable`.

## TODO
GraphQL, gRPC, Pagination, Long-Polling (see root CLAUDE.md).
