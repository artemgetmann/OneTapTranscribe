# TestLiveActivity MVP Scaffold

This folder contains a minimal architecture scaffold for validating Live Activity behavior before full OneTapTranscribe integration.

## Current Structure

- `ContentView.swift`: UI only, bound to `RecordingStateStore`.
- `Stores/RecordingStateStore.swift`: session orchestration and app state.
- `Services/LiveActivityService.swift`: ActivityKit lifecycle (start/update/stop).
- `Services/RecorderService.swift`: AVAudioRecorder-backed capture service.
- `Services/TranscriptionQueue.swift`: retrying async queue for transcription jobs.
- `Services/APIClient.swift`: backend proxy client (`POST /v1/transcribe` multipart).
- `Services/ClipboardService.swift`: clipboard wrapper.
- `Services/AppConfig.swift`: environment base URL selection.
- `RecordingAttributes.swift` + `RecordingWidget.swift`: shared Live Activity model + widget UI.

## What Works Today

- Start/stop flow from app UI using `RecorderService`.
- Live Activity request/update/end calls from `LiveActivityService`.
- Elapsed timer updates through state store tick loop (not inside the view).
- Upload + transcription call to backend proxy.
- Automatic retry on retryable network/server errors.
- Clipboard copy on successful transcription.

## Known Limitations

- Retry queue is in-memory only (not persisted across app relaunches yet).
- Widget stop button intent still returns success only; it does not call back into app state yet.
- iOS build requires a real Xcode project + full Xcode install (not just Command Line Tools).

## Next Integration Steps

1. Persist queue state to disk so uploads survive app restarts.
2. Wire `StopRecordingIntent` to app state (App Intents + shared container/app group).
3. Add unit tests for `RecordingStateStore` and `TranscriptionQueue`.
4. Add Info.plist key: `TRANSCRIPTION_BASE_URL` for environment switching.
5. Promote this scaffold into a full iOS app target with committed `.xcodeproj`.
