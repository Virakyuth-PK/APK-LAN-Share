#!/bin/bash
# Start / stop APK LAN Share (backend + built dashboard on one port).
# Usage: scripts/apk-share.sh start|stop|restart|status [--rebuild]
#        scripts/apk-share.sh share <path-to-apk>
# Safe to call from Apple Shortcuts (sets its own PATH).
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
RUN_DIR="$PROJECT_DIR/.run_logs"
PID_FILE="$RUN_DIR/server.pid"
LOG_FILE="$RUN_DIR/server.log"
PORT="${APK_SHARE_PORT:-8080}"

# Shortcuts/launchd give a minimal PATH. Add common Flutter/Dart locations.
export PATH="$HOME/fvm/default/bin:$HOME/development/flutter/bin:$HOME/flutter/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

mkdir -p "$RUN_DIR"

notify() {
  osascript -e "display notification \"$1\" with title \"APK LAN Share\"" >/dev/null 2>&1 || true
}

is_running() {
  [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

lan_ip() {
  ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1"
}

start() {
  if is_running; then
    echo "Already running (pid $(cat "$PID_FILE"))."
    open "http://127.0.0.1:$PORT"
    return 0
  fi

  command -v dart >/dev/null || { echo "dart not found in PATH"; notify "dart not found"; exit 1; }
  command -v flutter >/dev/null || { echo "flutter not found in PATH"; notify "flutter not found"; exit 1; }

  cd "$PROJECT_DIR"
  if [[ "${1:-}" == "--rebuild" || ! -f build/web/index.html ]]; then
    echo "Building web dashboard..."
    notify "Building dashboard (first run is slow)..."
    flutter pub get >>"$LOG_FILE" 2>&1 && flutter build web --release >>"$LOG_FILE" 2>&1 \
      || { echo "Build failed. See $LOG_FILE"; notify "Build failed"; exit 1; }
  fi

  cd "$BACKEND_DIR"
  dart pub get >>"$LOG_FILE" 2>&1
  nohup dart run bin/server.dart --port "$PORT" >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"

  for _ in $(seq 1 30); do
    curl -fs "http://127.0.0.1:$PORT/info" >/dev/null 2>&1 && break
    sleep 1
  done

  if curl -fs "http://127.0.0.1:$PORT/info" >/dev/null 2>&1; then
    echo "Running: http://127.0.0.1:$PORT  (LAN: http://$(lan_ip):$PORT)"
    notify "Running at http://$(lan_ip):$PORT"
    open "http://127.0.0.1:$PORT"
  else
    echo "Server failed to start. See $LOG_FILE"
    notify "Server failed to start"
    rm -f "$PID_FILE"
    exit 1
  fi
}

stop() {
  if is_running; then
    pid="$(cat "$PID_FILE")"
    pkill -P "$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
  # Catch orphaned dart child still holding the port.
  lsof -ti tcp:"$PORT" -sTCP:LISTEN 2>/dev/null | xargs kill 2>/dev/null || true
  echo "Stopped."
  notify "Stopped"
}

status() {
  if is_running; then echo "Running (pid $(cat "$PID_FILE")) on port $PORT"; else echo "Not running"; fi
}

# Start the server if needed, then send the given APK to it.
share() {
  local apk="${1:-}"
  if [[ -z "$apk" || ! -f "$apk" ]]; then
    echo "APK not found: $apk"; notify "APK not found"; exit 1
  fi
  case "$apk" in
    *.apk) ;;
    *) echo "Not an APK: $apk"; notify "Not an APK"; exit 1 ;;
  esac

  # Start the server if needed (start() also opens the dashboard).
  is_running || start ""

  local name enc resp
  name="$(basename "$apk")"
  enc="$(printf '%s' "$name" | perl -MURI::Escape -ne 'print uri_escape($_)' 2>/dev/null || printf '%s' "$name")"

  # Server API: POST /upload?name=<file>.apk with the raw APK as the body.
  if resp="$(curl -fsS -X POST -H 'Content-Type: application/octet-stream' \
      --data-binary "@$apk" "http://127.0.0.1:$PORT/upload?name=$enc" 2>&1)"; then
    echo "Shared: $name"
    notify "Shared $name"
    open "http://127.0.0.1:$PORT"
  else
    echo "Upload failed: $resp"
    notify "Upload failed"
    exit 1
  fi
}

case "${1:-}" in
  start)   start "${2:-}" ;;
  stop)    stop ;;
  restart) stop; sleep 1; start "${2:-}" ;;
  status)  status ;;
  share)   share "${2:-}" ;;
  *) echo "Usage: $0 start|stop|restart|status [--rebuild] | share <apk>"; exit 1 ;;
esac
