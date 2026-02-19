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

## Reliability Rules (Now)
- Transcription retries transient failures automatically.
- Retry policy keeps retry window open for at least 30 seconds.
- Backoff is exponential-ish to survive weak network + Render free-tier cold starts.

## Next Improvements (Priority Order)
1. Keep Dynamic Island stop control large and hard to mis-tap.
2. Tighten copy reliability and messaging when iOS blocks background clipboard writes.
3. Add "one-tap Shortcut capture" path as fallback for users who prefer no app-open start.
4. Continue R&D on true background start/stop path if Apple enables a reliable third-party route.
