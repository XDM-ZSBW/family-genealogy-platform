#!/bin/sh
# Cloud Run startup script
# Use PORT environment variable provided by Cloud Run
exec python -m uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}
