# Topic 4 — Realtime Networking

Four push/stream mechanisms compared.

## Files
- `HTTPPollingView.swift` — interval-based GET; simplest, wastes bandwidth.
- `SSEDemoView.swift` — Server-Sent Events via `URLSession.bytes(from:)`. Half-duplex text.
- `WebSocketDemoView.swift` — `URLSessionWebSocketTask`. Full-duplex binary/text.
- `PushNotificationDemoView.swift` — APNs flow, device token, payload format.

## When to use
Polling → simple infrequent. SSE → server→client feeds. WS → bidirectional. APNs → app-not-running.
