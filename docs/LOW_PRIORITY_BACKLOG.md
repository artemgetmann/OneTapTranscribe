# OneTapTranscribe Low-Priority Backlog

## P0-R&D: True Background Start From Control Center
Goal: achieve no-foreground recording start for third-party app flow if/when iOS allows a reliable path.

Current status:
1. Explicitly deferred after v1 ship because iOS frequently returns `Target is not foreground`.
2. Current shipped flow uses a reliable foreground handoff and works in practice.

R&D tasks:
1. Re-test each iOS/Xcode release for Control Widget + AppIntent behavior changes.
2. Track Apple forums/docs for officially supported background-start patterns.
3. Prototype alternatives only if they preserve reliability and do not regress shipped flow.

Exit criteria:
1. Start from Control Center succeeds without foreground handoff in repeated real-device tests.
2. No regression to stop/transcribe/copy reliability.

## P1: Share Audio -> Transcribe Shortcut Flow
Goal: keep a no-code fallback path while app UX evolves.

What it does:
1. User records in Voice Memos (or any app that exports audio).
2. User taps Share and picks one Shortcut action.
3. Shortcut posts audio to backend transcription endpoint.
4. Shortcut copies transcript to clipboard and shows notification.

Why this is useful:
1. Fast fallback when native capture has regressions.
2. Onboarding path for users not ready to install/trust an always-on recorder app.
3. Lower implementation cost than building another capture UI surface.

Current priority: low (app-first path already works end-to-end).

## P2: On-Device QA Checklist (iPhone + iPad + macOS)
Goal: strict pass/fail matrix to prevent false "it works" conclusions.

What it covers:
1. Permissions (mic, notifications, Live Activities).
2. Start/stop recording behavior.
3. Upload/transcription latency targets.
4. Clipboard correctness.
5. Background + lock-screen + app-switching behavior.
6. Failure paths (no network, 401/403, 5xx retry behavior).

Why this is useful:
1. Speeds iteration by making bugs reproducible quickly.
2. Prevents regressions during rapid changes.
3. Lets us compare behavior across iPhone, iPad, and macOS systematically.

Current priority: low-medium (promote after Dynamic Island/device behavior is stable).
