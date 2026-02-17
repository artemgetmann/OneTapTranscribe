import httpx
from fastapi.testclient import TestClient

from backend.app.main import OPENAI_TRANSCRIPTION_URL, app


def _sample_file():
    return {"file": ("sample.wav", b"audio-bytes", "audio/wav")}


def test_transcribe_success_default_model(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    captured: dict[str, object] = {}

    async def fake_post(self, url, headers=None, data=None, files=None):
        captured["url"] = url
        captured["headers"] = headers
        captured["data"] = data
        captured["files"] = files
        return httpx.Response(
            200,
            json={"text": "hello world", "duration": 2.75},
            request=httpx.Request("POST", url),
        )

    monkeypatch.setattr(httpx.AsyncClient, "post", fake_post)

    client = TestClient(app)
    response = client.post("/v1/transcribe", files=_sample_file())

    assert response.status_code == 200
    body = response.json()
    assert body["text"] == "hello world"
    assert body["durationSec"] == 2.75
    assert body["requestId"] == response.headers["x-request-id"]

    assert captured["url"] == OPENAI_TRANSCRIPTION_URL
    assert captured["headers"]["Authorization"] == "Bearer test-key"
    assert captured["data"]["model"] == "whisper-1"
    assert captured["data"]["response_format"] == "verbose_json"
    assert "file" in captured["files"]


def test_transcribe_success_without_duration(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")

    async def fake_post(self, url, headers=None, data=None, files=None):
        return httpx.Response(
            200,
            json={"text": "no duration payload"},
            request=httpx.Request("POST", url),
        )

    monkeypatch.setattr(httpx.AsyncClient, "post", fake_post)

    client = TestClient(app)
    response = client.post("/v1/transcribe", files=_sample_file())

    assert response.status_code == 200
    body = response.json()
    assert body["text"] == "no duration payload"
    assert body["durationSec"] is None


def test_transcribe_requires_api_key(monkeypatch):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)

    client = TestClient(app)
    response = client.post("/v1/transcribe", files=_sample_file())

    assert response.status_code == 500
    assert response.json() == {
        "errorCode": "CONFIG_ERROR",
        "message": "Server is missing OPENAI_API_KEY.",
        "retryable": False,
    }


def test_transcribe_maps_openai_rate_limit(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")

    async def fake_post(self, url, headers=None, data=None, files=None):
        return httpx.Response(
            429,
            json={
                "error": {
                    "message": "Rate limit exceeded.",
                    "code": "rate_limit_exceeded",
                }
            },
            request=httpx.Request("POST", url),
        )

    monkeypatch.setattr(httpx.AsyncClient, "post", fake_post)

    client = TestClient(app)
    response = client.post("/v1/transcribe", files=_sample_file())

    assert response.status_code == 429
    assert response.json() == {
        "errorCode": "OPENAI_RATE_LIMIT_EXCEEDED",
        "message": "Rate limit exceeded.",
        "retryable": True,
    }


def test_transcribe_validation_error_for_missing_file(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    client = TestClient(app)

    response = client.post("/v1/transcribe", data={"model": "whisper-1"})

    assert response.status_code == 422
    body = response.json()
    assert body["errorCode"] == "VALIDATION_ERROR"
    assert body["retryable"] is False
    assert isinstance(body["message"], str)
