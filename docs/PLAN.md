# OneTapTranscribe Execution Plan (App-First)

## Why This Plan
- Shortcut-only is fast but hits a hard UX ceiling: no custom Live Activity/Dynamic Island controls.
- Your differentiator is non-invasive recording control while multitasking.
- Therefore: build iPhone app first, keep scope brutally small, then expand.

## Decision Snapshot
- Current 80/20 product decision and iOS constraint notes are tracked in `docs/ROADMAP_80_20.md`.

## Current Status (2026-02-19)
- iOS app target builds and runs with Live Activity widget extension embedded.
- Control Center start action is wired through App Intent and currently prioritizes reliability by foregrounding app on start.
- Dynamic Island / lock-screen UI includes stop controls that work from Live Activity surfaces.
- Core flow is working: record -> stop -> upload/transcribe via backend -> copy transcript to clipboard.
- Backend proxy path (`POST /v1/transcribe`) is validated in local runs.
- Cloud readiness is prepared: runtime backend URL/token settings in app and hosting guide in `docs/HOSTING.md`.

## Immediate Next Moves (High Leverage)
1. Replace deep-link stop with full background-safe App Intent + app group command channel.
2. Persist `TranscriptionQueue` to disk (survive app kill/relaunch).
3. Add deterministic failure UI states for auth errors (401/403) vs retryable network/server errors.
4. Add a strict device QA script and capture baseline metrics:
   - stop-to-transcript latency
   - retry success rate on flaky network
   - Live Activity state consistency under app switching

## Direct Answer About Voice Memos + Share Sheet
- You do **not** invoke the same shortcut twice.
- But you do perform two user actions:
1. Record in Voice Memos.
2. Share that memo into the transcribe shortcut.
- That friction is exactly why app-native capture is better for this product.

## MVP Definition (v1 iPhone)
1. One tap to start recording.
2. Live Activity shows recording state/timer and stop action.
3. User can leave app; recording continues.
4. On stop, audio uploads to backend proxy -> Whisper.
5. Transcript is copied to clipboard automatically.
6. If network is weak/drops, upload retries automatically until success.
7. Support recordings up to 20 minutes.

## Out of Scope (v1)
- iPad/macOS parity.
- Transcript history/editor.
- Speaker diarization.
- Offline STT.

## Architecture

### iOS App (SwiftUI)
- `RecorderService`
  - Starts/stops microphone capture.
  - Persists recording file to app storage.
  - Tracks elapsed time.
- `RecordingStateStore`
  - Single source of truth for UI + Live Activity.
  - States: `idle`, `recording`, `stopping`, `uploading`, `done`, `failed`.
- `LiveActivityService`
  - Starts/updates/ends ActivityKit activity.
  - Exposes stop action route into app.
- `TranscriptionQueue`
  - Durable queue for pending uploads.
  - Retry with exponential backoff for transient network failures.
- `APIClient`
  - Sends multipart audio to proxy endpoint.
  - Parses transcript response.
- `ClipboardService`
  - Copies transcript on success.
  - Emits local success notification.

### Backend Proxy (Minimal)
- Single endpoint: `POST /v1/transcribe`
- Responsibilities:
  - Validate auth from app.
  - Forward audio to Whisper.
  - Normalize response payload.
  - Return transcript text + metadata.
- Keep provider key server-side only.

## Proposed Project Layout
- `ios/OneTapTranscribe/` (new Xcode project root)
- `ios/OneTapTranscribe/App/` (App entry + screens)
- `ios/OneTapTranscribe/Core/Recording/`
- `ios/OneTapTranscribe/Core/LiveActivity/`
- `ios/OneTapTranscribe/Core/Transcription/`
- `ios/OneTapTranscribe/Core/Clipboard/`
- `ios/OneTapTranscribeWidget/` (widget extension for Live Activity)
- `backend/` (tiny proxy service)
- `docs/` (product + technical docs)

## Milestones

### M0 - Bootstrap (Day 1)
1. Create Xcode iOS app + widget extension.
2. Wire existing Live Activity spike logic into real project shell.
3. Add local environment config for proxy base URL.
4. Confirm app builds and runs on iPhone simulator/device.

Acceptance:
- Start/stop UI works.
- Live Activity appears and updates timer.

### M1 - Recording Engine (Day 1-2)
1. Implement `RecorderService` with background recording config.
2. Persist output audio file with deterministic naming.
3. Add state transitions and guardrails for invalid taps.
4. Handle interruptions (phone call/audio session changes) safely.

Acceptance:
- 20-minute recording completes without crash.
- Switching apps does not stop recording unexpectedly.

### M2 - Transcription Pipeline (Day 2-3)
1. Build `TranscriptionQueue` with persisted pending jobs.
2. Implement `APIClient` multipart upload to proxy.
3. Add automatic retry policy:
   - Exponential backoff.
   - Retry on network/5xx.
   - Stop retry on 4xx auth/validation errors.
4. Copy transcript to clipboard on success.

Acceptance:
- Stop -> transcript copied in normal network path.
- Weak Wi-Fi / Wi-Fi->cellular transitions recover automatically.

### M3 - Proxy Backend (Day 2-3 in parallel)
1. Implement `POST /v1/transcribe`.
2. Stream or forward uploaded audio to Whisper API.
3. Return stable JSON contract to app.
4. Add request logging and error classification.

Acceptance:
- Endpoint handles files up to 20-minute target size.
- Clear response for success, retryable error, non-retryable error.

### M4 - Hardening + Device QA (Day 4)
1. Real-device testing matrix.
2. Battery/foreground/background sanity checks.
3. Retry idempotency (no duplicate transcript copies).
4. UX pass on notification and error messaging.

Acceptance:
- >=95% success across test matrix below.

## API and Interface Contracts

### App -> Proxy Request
- Multipart form fields:
  - `file` (audio)
  - `model` (default `whisper-1`)
  - optional `language`
  - optional `prompt`

### Proxy -> App Response
- Success:
  - `text` (string transcript)
  - `durationSec` (number)
  - `requestId` (string)
- Error:
  - `errorCode` (string)
  - `message` (string)
  - `retryable` (boolean)

## Test Matrix (Must Pass)
1. 30-second recording on stable Wi-Fi.
2. 5-minute recording on stable Wi-Fi.
3. 20-minute recording on stable Wi-Fi.
4. Upload starts on weak Wi-Fi.
5. Wi-Fi drops mid-upload, cellular resumes.
6. Proxy returns transient 500, retries succeed.
7. Proxy returns 401/403, app stops retry and surfaces error.
8. App background/foreground transitions during recording and upload.
9. Live Activity start/update/stop always reflects real state.
10. Clipboard contains exact transcript after success.

## Risks and Mitigations
- Risk: Background recording/upload behavior varies by device conditions.
  - Mitigation: early real-device testing, not simulator-only.
- Risk: Large file uploads fail on unstable networks.
  - Mitigation: durable queue + retry/backoff + resumable strategy later if needed.
- Risk: Live Activity action handling edge cases.
  - Mitigation: keep stop action minimal and route through central state store.

## Deferred / Lower Priority
- Share Sheet transcription shortcut flow and expanded cross-device QA checklist are moved to `docs/LOW_PRIORITY_BACKLOG.md`.
- Reason:
1. They do not block the app-first MVP loop (record -> transcribe -> clipboard).
2. They are leverage items to improve adoption and test discipline after base stability.

## Shipping Gate (v1)
Ship only when:
1. Core loop works end-to-end without manual recovery in normal conditions.
2. Network transitions recover automatically in test matrix.
3. Live Activity behavior is stable on iPhone target devices.
4. 20-minute recordings are consistently transcribed and copied to clipboard.
