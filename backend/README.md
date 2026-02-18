# Backend Transcription Proxy

Minimal FastAPI service that proxies multipart audio transcription requests to OpenAI.

## API

`POST /v1/transcribe`

Multipart form fields:
- `file` (required)
- `model` (optional, default `whisper-1`)
- `language` (optional)
- `prompt` (optional)

Success response:

```json
{
  "text": "transcribed text",
  "durationSec": 12.34,
  "requestId": "f9cc7f47-f9ea-4f8a-bf2a-2ecf74f96e6a"
}
```

Error response:

```json
{
  "errorCode": "UPSTREAM_ERROR",
  "message": "human-readable message",
  "retryable": false
}
```

Health check:

`GET /health`

```json
{
  "status": "ok",
  "uptimeSec": 12.34,
  "hasOpenAIKey": true,
  "clientTokenRequired": true
}
```

## Run locally

1. Create virtual environment and install dependencies:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

2. Set OpenAI API key:

```bash
export OPENAI_API_KEY="your-api-key"
```

Optional hardening for public hosting:

```bash
export APP_CLIENT_TOKEN="random-long-token"
export CORS_ALLOW_ORIGINS="https://your-web-client.example.com"
```

If `APP_CLIENT_TOKEN` is set, `/v1/transcribe` requires:
- `Authorization: Bearer <token>` header, or
- `x-app-token: <token>` header

3. Start server:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Production-compatible start command:

```bash
./start.sh
```

`start.sh` respects `PORT` automatically (`${PORT:-8000}`), so it works on Render/Railway/Fly.

## Run tests

From repository root:

```bash
pytest backend/tests -q
```

## Deploy quickly (Render / Railway style)

Build command:

```bash
pip install -r requirements.txt
```

Start command:

```bash
./start.sh
```

Environment variables required:
- `OPENAI_API_KEY`

Recommended:
- `APP_CLIENT_TOKEN`
- `CORS_ALLOW_ORIGINS`
