# Android Studio Run Configuration

This project includes pre-configured run configurations in `.idea/runConfigurations/`:

- **Run App With Server** (Compound) — starts backend + Flutter Web in Chrome together
- **Start Backend Server** — runs `backend/bin/server.dart --port 8080`
- **Flutter Web (Chrome)** — runs `flutter run -d chrome --web-port 5000 --web-hostname 127.0.0.1`

## Usage in Android Studio

1. Open the project in Android Studio
2. Select "Run App With Server" from the run dropdown (top toolbar)
3. Click the green ▶ button — it will launch both the companion server and the Flutter web app in Chrome
4. To stop both: click the red ⏹ stop button in Android Studio

## Alternative: Bash script

```bash
cd apk-lan-share
./run_app_with_server.sh
```

Ctrl+C stops both backend and Flutter.

Logs: `.run_logs/backend_*.log` and `.run_logs/flutter_*.log`

## Notes

- Backend binds `0.0.0.0:8080` so LAN devices can connect (same Wi-Fi)
- Flutter runs on `http://127.0.0.1:5000` with backend on `:8080` — CORS is already enabled
