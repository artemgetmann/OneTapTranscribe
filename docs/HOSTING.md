# OneTapTranscribe Hosting Guide

## Do You Need Hosting?
- Yes, if you want transcription to work away from your laptop.
- No, only for local testing (`http://127.0.0.1:8000` on your Mac).

## Deployment Modes

### Mode A: Public Beta (Fast Validation)
- `APP_CLIENT_TOKEN` unset.
- Anyone with endpoint can call `/v1/transcribe`.
- Best for testing demand quickly.
- Requires strict spend cap in OpenAI billing dashboard.

### Mode B: Private/Invite-Only
- Set `APP_CLIENT_TOKEN` to a strong secret.
- App must send `Authorization: Bearer <token>`.
- Best for controlled rollout.

Switch between A/B by changing one env var and redeploying.

## Minimal Production Setup
1. Deploy `backend/` to any Python host (Render, Railway, Fly.io, VPS).
2. Set environment variables:
   - `OPENAI_API_KEY` (required)
   - `APP_CLIENT_TOKEN` (recommended)
   - `CORS_ALLOW_ORIGINS` (optional; web-only)
3. Use:
   - Build command: `pip install -r requirements.txt`
   - Start command: `./start.sh`
4. Verify health:
   - `GET https://<your-api-domain>/health`
5. In iOS app:
   - Tap gear icon -> Backend
   - Set backend URL to `https://<your-api-domain>`
   - If token is enabled, paste same token in `Client Token`
   - Save

Hosted beta endpoint currently used in this repo:
- `https://onetaptranscribe-api.onrender.com`

## Security Notes
- Never ship OpenAI API key in the iOS app.
- Keep key server-side only.
- If backend is public, set `APP_CLIENT_TOKEN` to prevent abuse.
- CORS is not auth. It does not stop direct server-side abuse.
- If your OpenAI key was ever exposed, rotate it immediately.

## Cost Control (Recommended Even in Public Beta)
1. Set a hard monthly budget limit in OpenAI.
2. Set usage alerts.
3. Keep Render service easy to suspend (kill switch).
4. If spend spikes, first action is to set `APP_CLIENT_TOKEN`.

## Tracking Usage Without Heavy Auth

If you do not want full user accounts yet, use this lightweight split:

1. Keep one codebase.
2. Run two Render services:
   - personal endpoint (private token)
   - public-beta endpoint (open or separate token)
3. Compare per-service logs and traffic.

This gives you directional attribution without adding full auth + billing now.

## Smoke Test (Device)
1. Start recording in app.
2. Stop from Dynamic Island.
3. Confirm transcript appears and is copied to clipboard.
4. Turn off laptop/Wi-Fi to confirm hosted backend works independently.
