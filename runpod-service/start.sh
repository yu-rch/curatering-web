#!/bin/bash

echo "Before cleanup:"
lsof -i :8888 || true

pkill -9 -f jupyter || true
pkill -9 -f lab || true
pkill -9 -f notebook || true

sleep 2

echo "After cleanup:"
lsof -i :8888 || true

echo "Starting FastAPI..."
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000