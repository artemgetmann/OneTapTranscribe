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

3. Start server:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## Run tests

From repository root:

```bash
pytest backend/tests -q
```
