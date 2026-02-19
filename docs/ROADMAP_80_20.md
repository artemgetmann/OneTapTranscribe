# OneTapTranscribe 80/20 Roadmap

Date: 2026-02-19

## North-Star Flow (Ideal)
1. User taps Control Center button.
2. Recording starts immediately without opening app.
3. User taps Stop on Dynamic Island.
4. Recording stops in background.
5. Transcript is generated and copied silently to clipboard.

This is the target UX for the product.

## Platform Constraint (Current)
- On current iOS behavior for third-party apps, recording start from Control Center can fail with `Target is not foreground`.
- In practice this blocks fully hidden background mic start for our app path.
- Result: app foreground handoff is currently required for reliable start.

## Shipped 80/20 Flow (Now)
1. User taps Control Center button.
2. App opens and starts recording reliably.
3. User returns to previous app if needed.
4. User stops from Dynamic Island.
5. App is brought forward to complete copy flow.
6. User swipes back to prior app.

This is the current release behavior because it is reliable on real devices.

## Reliability Policy (Now)
- Transcription retries automatically on retryable errors (network/5xx/429).
- Retry policy is tuned for Render free-tier cold starts.
- No manual retry button is required in the main UI for this path.

## Later R&D (Lower Priority)
1. Re-test true background start/stop each major iOS/Xcode update.
2. Investigate any new public APIs that allow no-open Control Center recording for third-party apps.
3. If platform support appears, migrate to North-Star flow.
