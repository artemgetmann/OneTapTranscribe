# OneTapTranscribe Hosting Guide

## Do You Need Hosting?
- Yes, if you want transcription to work away from your laptop.
- No, only for local testing (`http://127.0.0.1:8000` on your Mac).

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

## Security Notes
- Never ship OpenAI API key in the iOS app.
- Keep key server-side only.
- If backend is public, set `APP_CLIENT_TOKEN` to prevent abuse.

## Smoke Test (Device)
1. Start recording in app.
2. Stop from Dynamic Island.
3. Confirm transcript appears and is copied to clipboard.
4. Turn off laptop/Wi-Fi to confirm hosted backend works independently.
