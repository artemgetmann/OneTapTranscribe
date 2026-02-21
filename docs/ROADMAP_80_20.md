# OneTapTranscribe 80/20 Roadmap

## Goal
- Build the fastest possible speech-to-clipboard flow with minimal friction.
- Keep reliability first, then remove UX friction in controlled steps.

## Ideal Flow (Target)
1. User taps Control Center button.
2. Recording starts immediately in background.
3. User taps Stop in Dynamic Island (large stop control).
4. App transcribes and copies to clipboard without opening app UI.

## Current iOS Constraint (2026-02-19)
- Third-party app recording start from Control Center background path is not reliably allowed on real devices.
- Practical symptom in logs: `Target is not foreground`.
- Result: pure "never open app" flow is not stable enough to ship.

## Shipped 80/20 Flow (Now)
1. User taps Control Center button.
2. App is opened and recording starts reliably.
3. User switches back to previous app if needed.
4. User taps Stop from Dynamic Island.
5. Transcription finishes.
6. If clipboard can be written in current app state, text is copied.
7. If clipboard cannot be written in background, user gets notification to open app and copy.

Why this is the right tradeoff now:
- Reliability over fragile "magic" behavior.
- Still keeps interaction very short.
- Good enough to ship while platform constraints are investigated.

## Shipping Decision (2026-02-21)
- Marked as shipped with the reliable foreground-handoff flow.
- Product uses this as the default behavior in real usage.
- True hidden background start from Control Center is explicitly moved to R&D/backlog.

## Reliability Rules (Now)
- Every stopped recording is persisted as a pending transcription job before upload starts.
- Pending jobs are retried automatically and survive app relaunches.
- Retryable failures (`429`, `5xx`, network) use backoff and keep retrying until success.
- Audio interruptions (calls/Siri) auto-stop active recording and enqueue captured audio.
- iOS background limits still apply: retries progress fastest while app process is alive.

## Next Improvements (Priority Order)
1. Keep Dynamic Island stop control large and hard to mis-tap.
2. Tighten copy reliability and messaging when iOS blocks background clipboard writes.
3. Add "one-tap Shortcut capture" path as fallback for users who prefer no app-open start.
4. Continue R&D on true background start/stop path if Apple enables a reliable third-party route.
