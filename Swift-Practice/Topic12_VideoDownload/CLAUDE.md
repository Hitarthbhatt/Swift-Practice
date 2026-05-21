# Topic 12 — Video Download

Concurrent video downloader, two approaches in subfolders. Both: play/pause/resume, background, survive app kill, progress, quality/bitrate selection.

## Subfolders
- `BackgroundURLSession/` — generic file download via `URLSessionDownloadTask` + background config. Best when video is a plain file (MP4).
- `HLSDownload/` — streaming download via `AVAssetDownloadURLSession` + `AVAssetDownloadTask`. The canonical iOS way for HLS (`.m3u8`).

## BackgroundURLSession files
- `VideoDownloadModels.swift` — `VideoItem`, `VideoVariant`, `VideoQuality`, `DownloadRecord` (Codable, persisted), `DownloadStatus`.
- `DownloadStore.swift` — disk persistence: `records.json`, `resume/` blobs, `completed/` files (Application Support).
- `VideoDownloadManager.swift` — `NSObject` singleton, one background `URLSession`, `URLSessionDownloadDelegate`. Concurrent tasks keyed by `videoID`.
- `VideoDownloadViewModel.swift` — `@Observable`. Catalog + per-item quality + controls + `AVPlayer` playback.
- `VideoDownloadDemoView.swift` — list rows: quality picker, progress, transport buttons, `VideoPlayer`.

## HLSDownload files
- `HLSDownloadModels.swift` — `HLSAsset`, `HLSQuality`, `HLSRecord` (stores `relativePath`), `HLSStatus`.
- `HLSDownloadManager.swift` — `NSObject` singleton, `AVAssetDownloadURLSession`, `AVAssetDownloadDelegate`.
- `HLSDownloadViewModel.swift` — `@Observable`. Mirror of the URLSession VM.
- `HLSDownloadDemoView.swift` — same UI shape; plays offline `AVURLAsset`.

## Shared
- `AppDelegate+BackgroundDownloads.swift` — `handleEventsForBackgroundURLSession` routes the OS completion handler to the matching manager by session identifier.

## How each feature is satisfied
| Feature | URLSession | HLS (AVAssetDownload) |
|---|---|---|
| Play / pause / resume | `cancel(byProducingResumeData:)` → `downloadTask(withResumeData:)` | `task.suspend()` / `task.resume()` |
| Background download | `URLSessionConfiguration.background` | same |
| Survive app kill | `records.json` + `getAllTasks()` re-bind via `taskDescription` | UserDefaults records + `getAllTasks()` |
| Progress | `didWriteData` (bytes) | `didLoad timeRange` (fraction of duration) |
| Quality | pick variant URL per `VideoQuality` | `AVAssetDownloadTaskMinimumRequiredMediaBitrateKey` |
| Bitrate | variant `approxBitrate` | min-required-bitrate option |
| Playback | `AVPlayerItem(url:)` from `completed/` | `AVPlayerItem(asset:)` from re-located bundle |

## Concurrency model
- One background `URLSession` per approach (singleton — two sessions with the same identifier crashes).
- `delegateQueue = .main`, so every callback is on the main thread. Manager is MainActor-isolated by default (project setting); delegate methods are `nonisolated` and hop via `MainActor.assumeIsolated` (safe — queue is main).
- `didFinishDownloadingTo` moves the temp file **synchronously** inside the callback — the temp URL is invalid once it returns.

## Interview talking points
- Why background `URLSession` vs `AVAssetDownloadTask`? Plain files → URLSession (full control, resume data). HLS streams → AVAssetDownload (handles the playlist + segments, offline FairPlay bundle).
- How does download survive app kill? Background session tasks are owned by the OS daemon, not the app. On relaunch `getAllTasks()` returns live tasks; `taskDescription` re-associates them with persisted records.
- Why store `relativePath` for HLS, not absolute? The app container path changes between launches; rebuild from `NSHomeDirectory()`.
- Resume data vs suspend/resume: URLSession needs an explicit resume-data blob (server must support range requests / `ETag`); AVAssetDownloadTask resumes its partial bundle natively.
- Background completion handler: must be called after UI updates so the OS can snapshot the app; ignoring it risks termination warnings.

## Limits / notes
- For real device background completion, add `Background Modes` capability if you extend to fetch/processing; plain background URLSession works without extra entitlement.
- Demo MP4s are public sample files used as stand-in "quality variants" (different files, not true re-encodes of one source).
- HLS demo uses Apple bipbop public test streams (same as Topic 11).
