# OneTapTranscribe

OneTapTranscribe is an iOS-first transcription app:

- tap `Start` to record
- stop from app or Dynamic Island
- audio uploads to backend
- transcript is copied to clipboard

Current target is fast validation, not heavy productization.

## Current Status

- iPhone app + widget extension running
- Dynamic Island stop path working
- backend proxy deployed on Render
- hosted API is currently open for beta testing

## Try It (Hosted Backend)

1. Clone repo.
2. Open `OneTapTranscribe/OneTapTranscribe.xcodeproj` in Xcode.
3. Select scheme `OneTapTranscribe`.
4. Run on iPhone (recommended) or simulator.
5. In app settings (gear icon), set:
   - Backend URL: `https://onetaptranscribe-api.onrender.com`
   - Client Token: leave empty (current public-beta mode)
6. Tap `Start`, then `Stop`, confirm transcript appears and copies to clipboard.

## Self-Host Backend

If you want your own backend/key:

1. Go to `backend/`.
2. Follow `backend/README.md`.
3. Deploy to Render/Railway/Fly/VPS.
4. Set your app Backend URL to your own domain.

## Public-Beta Policy (Current)

- Hosted API is free for early testing.
- No SLA.
- Abuse controls and pricing can be enabled later without app rewrite.
- Service can be paused any time if costs spike.

## Docs

- Setup and app flow: `OneTapTranscribe/OneTapTranscribe/TestLiveActivity/README.md`
- Hosting and security modes: `docs/HOSTING.md`
- Execution plan: `docs/PLAN.md`
- Lower-priority backlog: `docs/LOW_PRIORITY_BACKLOG.md`
