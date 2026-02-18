from __future__ import annotations

import json
import logging
import os
import time
import uuid
from dataclasses import dataclass
from typing import Any

import httpx
from fastapi import FastAPI, File, Form, Request, UploadFile
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

OPENAI_TRANSCRIPTION_URL = "https://api.openai.com/v1/audio/transcriptions"
RETRYABLE_STATUS_CODES = {429, 500, 502, 503, 504}

logger = logging.getLogger("transcription_proxy")
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)
logger.setLevel(logging.INFO)


@dataclass
class ServiceError(Exception):
    status_code: int
    error_code: str
    message: str
    retryable: bool


def _log(event: str, **fields: Any) -> None:
    # Emit machine-parseable JSON logs so request-level tracing works in production.
    payload = {"event": event, **fields}
    logger.info(json.dumps(payload, ensure_ascii=True, separators=(",", ":")))


def _request_id(request: Request) -> str:
    return getattr(request.state, "request_id", "unknown")


def _error_response(
    request_id: str,
    status_code: int,
    error_code: str,
    message: str,
    retryable: bool,
) -> JSONResponse:
    _log(
        "request.error",
        requestId=request_id,
        statusCode=status_code,
        errorCode=error_code,
        retryable=retryable,
    )
    return JSONResponse(
        status_code=status_code,
        headers={"x-request-id": request_id},
        content={
            "errorCode": error_code,
            "message": message,
            "retryable": retryable,
        },
    )


def _extract_duration(payload: dict[str, Any]) -> float | None:
    # OpenAI formats may vary by model/response format; normalize what we can.
    duration = payload.get("duration") or payload.get("audio_duration")
    if isinstance(duration, (int, float)):
        return float(duration)
    return None


def _parse_upstream_error(response: httpx.Response) -> tuple[str, str]:
    default_message = f"OpenAI returned status {response.status_code}."
    error_code = "UPSTREAM_ERROR"
    try:
        payload = response.json()
    except ValueError:
        return error_code, default_message

    error_obj = payload.get("error") if isinstance(payload, dict) else None
    if not isinstance(error_obj, dict):
        return error_code, default_message

    message = error_obj.get("message")
    raw_code = error_obj.get("code")
    if isinstance(raw_code, str) and raw_code:
        normalized = raw_code.upper().replace("-", "_")
        error_code = f"OPENAI_{normalized}"
    if isinstance(message, str) and message:
        default_message = message
    return error_code, default_message


def _csv_env(name: str) -> list[str]:
    raw = os.getenv(name, "")
    return [item.strip() for item in raw.split(",") if item.strip()]


def _extract_bearer_token(authorization: str | None) -> str | None:
    if not authorization:
        return None

    parts = authorization.split(" ", 1)
    if len(parts) != 2:
        return None

    scheme, token = parts[0].strip().lower(), parts[1].strip()
    if scheme != "bearer" or not token:
        return None
    return token


def _assert_client_token(request: Request) -> None:
    required_token = os.getenv("APP_CLIENT_TOKEN")
    if not required_token:
        return

    # Accept standard bearer auth first, with x-app-token fallback for constrained clients.
    bearer = _extract_bearer_token(request.headers.get("authorization"))
    fallback = request.headers.get("x-app-token")
    provided_token = bearer or (fallback.strip() if fallback else None)

    if provided_token != required_token:
        raise ServiceError(
            status_code=401,
            error_code="UNAUTHORIZED",
            message="Invalid client token.",
            retryable=False,
        )


async def _forward_to_openai(
    api_key: str,
    file: UploadFile,
    model: str,
    language: str | None,
    prompt: str | None,
) -> dict[str, Any]:
    form_data: dict[str, str] = {"model": model, "response_format": "verbose_json"}
    if language:
        form_data["language"] = language
    if prompt:
        form_data["prompt"] = prompt

    # Forward file handle directly to avoid loading larger recordings entirely into memory.
    await file.seek(0)
    files = {
        "file": (
            file.filename or "audio",
            file.file,
            file.content_type or "application/octet-stream",
        )
    }
    headers = {"Authorization": f"Bearer {api_key}"}

    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(60.0)) as client:
            response = await client.post(
                OPENAI_TRANSCRIPTION_URL,
                headers=headers,
                data=form_data,
                files=files,
            )
    except httpx.TimeoutException as exc:
        raise ServiceError(
            status_code=504,
            error_code="UPSTREAM_TIMEOUT",
            message="Timed out while waiting for OpenAI transcription.",
            retryable=True,
        ) from exc
    except httpx.RequestError as exc:
        raise ServiceError(
            status_code=503,
            error_code="UPSTREAM_UNAVAILABLE",
            message="Could not connect to OpenAI transcription service.",
            retryable=True,
        ) from exc

    if response.status_code >= 400:
        error_code, message = _parse_upstream_error(response)
        raise ServiceError(
            status_code=response.status_code,
            error_code=error_code,
            message=message,
            retryable=response.status_code in RETRYABLE_STATUS_CODES,
        )

    try:
        payload = response.json()
    except ValueError as exc:
        raise ServiceError(
            status_code=502,
            error_code="UPSTREAM_INVALID_RESPONSE",
            message="OpenAI returned invalid JSON.",
            retryable=True,
        ) from exc

    if not isinstance(payload, dict):
        raise ServiceError(
            status_code=502,
            error_code="UPSTREAM_INVALID_RESPONSE",
            message="OpenAI returned unexpected payload format.",
            retryable=True,
        )
    return payload


def create_app() -> FastAPI:
    app = FastAPI(title="OneTapTranscribe Proxy")
    started_at = time.perf_counter()

    allow_origins = _csv_env("CORS_ALLOW_ORIGINS")
    if allow_origins:
        # CORS is optional for native iOS calls, but needed for browser/Shortcut/web clients.
        app.add_middleware(
            CORSMiddleware,
            allow_origins=allow_origins,
            allow_credentials=False,
            allow_methods=["GET", "POST", "OPTIONS"],
            allow_headers=["*"],
        )

    @app.middleware("http")
    async def request_context(request: Request, call_next):
        request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
        request.state.request_id = request_id
        started = time.perf_counter()

        try:
            response = await call_next(request)
        except Exception:
            duration_ms = round((time.perf_counter() - started) * 1000, 2)
            _log(
                "request.unhandled_exception",
                requestId=request_id,
                method=request.method,
                path=request.url.path,
                durationMs=duration_ms,
            )
            raise

        duration_ms = round((time.perf_counter() - started) * 1000, 2)
        response.headers["x-request-id"] = request_id
        _log(
            "request.completed",
            requestId=request_id,
            method=request.method,
            path=request.url.path,
            statusCode=response.status_code,
            durationMs=duration_ms,
        )
        return response

    @app.exception_handler(ServiceError)
    async def service_error_handler(request: Request, exc: ServiceError):
        return _error_response(
            request_id=_request_id(request),
            status_code=exc.status_code,
            error_code=exc.error_code,
            message=exc.message,
            retryable=exc.retryable,
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(request: Request, exc: RequestValidationError):
        errors = exc.errors()
        message = "Invalid request."
        if errors and isinstance(errors[0], dict):
            message = errors[0].get("msg", message)
        return _error_response(
            request_id=_request_id(request),
            status_code=422,
            error_code="VALIDATION_ERROR",
            message=message,
            retryable=False,
        )

    @app.exception_handler(Exception)
    async def unhandled_error_handler(request: Request, exc: Exception):
        _log(
            "request.exception",
            requestId=_request_id(request),
            errorType=exc.__class__.__name__,
        )
        return _error_response(
            request_id=_request_id(request),
            status_code=500,
            error_code="INTERNAL_ERROR",
            message="Internal server error.",
            retryable=False,
        )

    @app.get("/health")
    async def health():
        return {
            "status": "ok",
            "uptimeSec": round(time.perf_counter() - started_at, 2),
            "hasOpenAIKey": bool(os.getenv("OPENAI_API_KEY")),
            "clientTokenRequired": bool(os.getenv("APP_CLIENT_TOKEN")),
        }

    @app.post("/v1/transcribe")
    async def transcribe(
        request: Request,
        file: UploadFile = File(...),
        model: str = Form("whisper-1"),
        language: str | None = Form(None),
        prompt: str | None = Form(None),
    ):
        request_id = _request_id(request)
        _assert_client_token(request)
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ServiceError(
                status_code=500,
                error_code="CONFIG_ERROR",
                message="Server is missing OPENAI_API_KEY.",
                retryable=False,
            )

        payload = await _forward_to_openai(
            api_key=api_key,
            file=file,
            model=model,
            language=language,
            prompt=prompt,
        )

        text = payload.get("text")
        if not isinstance(text, str) or not text.strip():
            raise ServiceError(
                status_code=502,
                error_code="UPSTREAM_INVALID_RESPONSE",
                message="OpenAI response did not include transcription text.",
                retryable=True,
            )

        return {
            "text": text,
            "durationSec": _extract_duration(payload),
            "requestId": request_id,
        }

    return app


app = create_app()
