# Topic 8 — Network Resilience

Retry, breaker, token refresh.

## Files
- `RetryPolicy.swift` — `ExponentialBackoff` + `LinearBackoff` strategies. Jitter optional.
- `CircuitBreaker.swift` — closed/open/half-open state machine. Threshold + cooldown.
- `OAuthTokenManager.swift` — actor. Refresh dedup so concurrent 401s trigger one refresh.
- `NetworkResilienceViewModel.swift` — wires policies into mock client.
- `NetworkResilienceDemoView.swift` — UI to trigger failure modes.

## Rules
- Retry only idempotent verbs (GET, PUT, DELETE).
- Breaker opens on consecutive failures, not single.
- Refresh = serialized via actor to prevent stampede.
