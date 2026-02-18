#!/usr/bin/env sh
set -eu

# Use platform-provided PORT in production, default to 8000 for local runs.
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
