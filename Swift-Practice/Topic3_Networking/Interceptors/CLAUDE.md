# Topic 3 — Network Interceptors (chain of responsibility)

Simpler interceptor system (replaces the old 3-protocol chain). **One** protocol; each interceptor wraps `next`
(Alamofire/OkHttp style). Auth, Retry (exponential backoff + jitter), Log. Interactive screen:
tap a scenario → Run → see the chain's log lines.

## Core idea
```swift
typealias Responder = (HTTPRequest) async throws -> HTTPResponse
protocol Interceptor {
    func intercept(_ request: HTTPRequest, next: Responder) async throws -> HTTPResponse
}
```
`APIClient.send` folds the array right-to-left around the transport, so `[Auth, Retry, Log]` becomes
`Auth(Retry(Log(transport)))`. Each interceptor decides what to do before/after calling `next`.

## Files
- `Interceptor.swift` — `HTTPRequest`, `HTTPResponse`, `Responder`, `Interceptor`, `Recorder` (log sink).
- `AuthInterceptor.swift` — adds `Authorization: Bearer …`, then `next`.
- `RetryInterceptor.swift` — loops; on 5xx/error waits `base · 2^(n-1) · rand(0.8…1.2)` (capped), retries.
- `LogInterceptor.swift` — logs `➡️` request and `⬅️` response/error around `next`.
- `MockServer.swift` — transport stub: `failFirst` 503s then `finalStatus`, or fixed `alwaysStatus`.
- `APIClient.swift` — builds + runs the chain (capture-safe fold).
- `InterceptorScenarios.swift` — 4 scenarios feeding the demo.
- `NetworkInterceptorsView.swift` — interactive list.

## How each interceptor uses `next`
| Interceptor | Before next | After next |
|---|---|---|
| Auth | mutate request (add token) | — |
| Log | log request | log response/error |
| Retry | — | inspect result; on 5xx/error sleep backoff and call again |

## Backoff + jitter (why)
`delay = base · 2^(attempt-1)` grows fast so a struggling server gets breathing room. **Jitter**
(`×rand(0.8…1.2)`) spreads many clients' retries so they don't all hit at the same instant
(thundering herd). **Cap** stops delays growing unbounded. Mirrors Topic 8 `ExponentialBackoff`.

## Interview points
- Chain of responsibility: one protocol, composable, order matters (`[Auth, Retry, Log]`).
- Retry only **idempotent** verbs + **transient** failures (5xx, timeouts) — never 4xx like 401/400.
- The fold captures `let next = responder` per iteration — the classic loop-capture gotcha.
- Real frameworks: Alamofire `RequestInterceptor` (adapt + retry), URLSession via `URLProtocol`.
- Order trade-off: Retry outside Log → Log narrates every attempt; Auth outside Retry → token added once.
