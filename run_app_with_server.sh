#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
LOG_DIR="$PROJECT_DIR/.run_logs"
mkdir -p "$LOG_DIR"

BACKEND_LOG="$LOG_DIR/backend_$(date +%Y%m%d_%H%M%S).log"
FLUTTER_LOG="$LOG_DIR/flutter_$(date +%Y%m%d_%H%M%S).log"

cleanup() {
  echo "[run] Stopping backend..."
  kill "$BACKEND_PROC" 2>/dev/null || true
  pkill -P "$BACKEND_PROC" 2>/dev/null || true
  echo "[run] Stopped."
  exit 0
}

trap cleanup SIGINT SIGTERM EXIT

echo "[run] Starting backend on port 8080..."
cd "$BACKEND_DIR"
dart pub get >> "$BACKEND_LOG" 2>&1
dart run bin/server.dart --port 8080 --no-ui >> "$BACKEND_LOG" 2>&1 &
BACKEND_PROC=$!

# Give backend a moment to start
sleep 3

echo "[run] Starting Flutter web app (hot reload)..."
cd "$PROJECT_DIR"
flutter pub get --offline 2>/dev/null || flutter pub get
flutter run -d chrome --web-port 5000 --web-hostname 127.0.0.1 2>&1 | tee "$FLUTTER_LOG"
