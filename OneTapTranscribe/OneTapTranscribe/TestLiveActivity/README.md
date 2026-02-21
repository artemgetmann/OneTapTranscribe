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
- `RecordingAttributes.swift`: shared Live Activity model.
- `OneTapTranscribeWidgetExtension/RecordingLiveActivityWidget.swift`: Dynamic Island + lock-screen Live Activity UI.

## What Works Today

- Start/stop flow from app UI using `RecorderService`.
- Start/stop via Live Activity stop control (deep-link route back into app).
- Live Activity request/update/end calls from `LiveActivityService`.
- Elapsed timer updates through state store tick loop (not inside the view).
- Upload + transcription call to backend proxy.
- Automatic retry on retryable network/server errors.
- Pending transcription files persisted in app-group storage and resumed after relaunch.
- Audio-session interruption (call/Siri) auto-stops and queues captured audio for transcription.
- Clipboard copy on successful transcription.

## Known Limitations

- Deferred transcription queue persists pending files, but retry execution still depends on available app process time (iOS background execution limits apply).
- iOS build requires a real Xcode project + full Xcode install (not just Command Line Tools).
- Control Center start currently foregrounds app for reliability on real devices; true hidden background start remains R&D.

## Next Integration Steps

1. Replace deep-link stop with fully in-extension `AppIntent` + app group signaling.
2. Add unit tests for `RecordingStateStore` and `TranscriptionQueue`.
3. Add bounded retention cleanup policy for very old pending audio files.
4. Add transport security + env profile strategy for device testing endpoints.
5. Promote this scaffold into a fully split app/module structure (`Core`, `Features`, `Infra`).
