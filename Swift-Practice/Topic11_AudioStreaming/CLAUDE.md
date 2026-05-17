# Topic 11 — HLS Audio Streaming

Basic HLS audio player. AVPlayer + master playlist ABR. Quality cap via `preferredPeakBitRate`.

## Files
- `AudioPlayerViewModel.swift` — `@MainActor @Observable`. Wraps `AVPlayer`. Track list, transport, seek, quality.
- `AudioStreamingDemoView.swift` — SwiftUI UI. Now-playing header, scrubber, transport, quality picker, track list.

## Features
- Play / pause / toggle
- Next / previous (wraps)
- Seek (drag-then-release; scrubbing local-only until release)
- Quality picker → `AVPlayerItem.preferredPeakBitRate` (auto / 64k / 192k / 320k bits/sec)
- Periodic time observer drives progress
- `AVAudioSession.playback` for iOS

## How HLS multi-bitrate works
Master `.m3u8` lists variant playlists (different bandwidths). AVPlayer's ABR picks variant based on network + `preferredPeakBitRate`. `0` = unlimited (auto).

## Demo streams
Apple bipbop master playlists (public test streams).

## Limits
- No background audio entitlement here. Add `UIBackgroundModes: audio` in Info.plist if needed.
- Duration shows 0 for live streams (`.indefinite`).
- No now-playing lock-screen integration (skip MPRemoteCommandCenter for brevity).
