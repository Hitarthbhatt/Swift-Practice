# Topic 12 — Network Interceptor (async/await)

Composable middleware: adapt, retry, observe.

## Files
- `NetworkInterceptor.swift` — `RequestAdapter`, `RequestRetrier`, `NetworkEventObserver`, `RetryDecision`, `NetworkResponse`, `NetworkError`.
- `APIClient.swift` — actor. Runs chain: adapt → send → observe → retry loop. Caps with `maxRetries`. `NetworkTransport` injection point.
- `HeaderInterceptor.swift` — adapter. Injects static headers (Accept, X-Client) without clobbering existing values.
- `AuthInterceptor.swift` — actor. Adapter (Bearer header) + retrier (401 → refresh → replay). Dedups concurrent refreshes via in-flight `Task`.
- `RetryInterceptor.swift` — retrier. Exponential backoff + jitter. Idempotent verbs only. Configurable status codes + transient `URLError` set.
- `LoggingInterceptor.swift` — observer. Read-only event taps for request/response/failure.
- `MockTransport.swift` — actor. Configurable behavior (success / fail / sequence). Substitutes `URLSession` in the demo.
- `NetworkInterceptorViewModel.swift` — wires chain. Streams log events via `AsyncStream` so observer stays `Sendable`.
- `NetworkInterceptorDemoView.swift` — scenarios: happy path, 401 refresh + replay, transient failure + retry, permanent 5xx.

## Rules
- Adapters mutate, retriers decide, observers only read.
- Retry only on idempotent verbs (GET/PUT/DELETE/HEAD/OPTIONS).
- 401 refresh deduped via actor + in-flight `Task` (no thundering herd).
- Adapter order matters: header adapter before auth so auth wins on `Authorization`.
- First retrier returning a non-`.doNotRetry` decision short-circuits the chain.
- Use `.retryWith(newRequest)` to replace the request — `retry` alone re-adapts the original (re-injects the *new* token because `AuthInterceptor.adapt` reads current state).
- `Configuration.maxRetries` is the hard ceiling — retrier decisions ignored past it.

## Interview talking points
- Why split adapter / retrier / observer? Single responsibility. Auth happens to be both, but each role is independently testable.
- Why actor for `AuthInterceptor`? Concurrent 401s would otherwise race on refresh.
- Why `RetryDecision` enum vs Bool? Lets retrier express delay and request replacement without out-of-band state.
- Why injectable `NetworkTransport`? `URLSession` in prod, `MockTransport` in tests — no `URLProtocol` subclass needed.
- Why observer pattern? Logging/metrics/analytics are cross-cutting and read-only — separating them keeps retriers from leaking concerns.
