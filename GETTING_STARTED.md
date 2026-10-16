# Getting Started

Share Android `.apk` files over Wi-Fi: drop an APK in the dashboard, scan the QR code on a phone, download.

## Requirements

- macOS (the one-click Shortcut is macOS only; the server itself runs anywhere Flutter runs)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.24+ (includes Dart)
- Chrome (or any browser)
- Computer and phone on the **same Wi-Fi**

Check: `flutter --version`

## Clone and run

```bash
git clone <repo-url> apk-lan-share
cd apk-lan-share
./scripts/apk-share.sh start
```

First run builds the web dashboard (1-3 min). Later runs start in seconds.
Browser opens at <http://127.0.0.1:8080>. Terminal prints your LAN URL.

```bash
./scripts/apk-share.sh stop      # stop server
./scripts/apk-share.sh restart   # stop + start
./scripts/apk-share.sh status    # running?
./scripts/apk-share.sh start --rebuild   # rebuild dashboard after pulling UI changes
```

Logs: `.run_logs/server.log`. Staged APKs: `backend/public/`.

Change port: `APK_SHARE_PORT=9090 ./scripts/apk-share.sh start`

## Use it

1. Drop an `.apk` anywhere on the dashboard (or click to browse).
2. Scan the QR code with the phone camera.
3. Phone downloads the APK.

## Apple Shortcuts (one-click start / stop)

Make two shortcuts in the **Shortcuts** app. Replace `/path/to/apk-lan-share` with your clone path.

**Shortcut 1: "Start APK Share"**
1. New Shortcut, name it `Start APK Share`.
2. Add action **Run Shell Script**.
3. Shell: `zsh`. Input: none. Script:
   ```bash
   /path/to/apk-lan-share/scripts/apk-share.sh start
   ```
4. (Optional) Add **Show Result** after it.

**Shortcut 2: "Stop APK Share"**
Same steps, script:
```bash
/path/to/apk-lan-share/scripts/apk-share.sh stop
```

Optional: shortcut details (i) → **Add to Menu Bar** / **Add to Dock**, or run via Spotlight / Siri ("Start APK Share").

The script sets its own `PATH` (looks in `~/fvm/default/bin`, `~/development/flutter/bin`, `~/flutter/bin`, Homebrew). If Flutter lives elsewhere, edit the `export PATH=` line in `scripts/apk-share.sh`.

## Developing the app

Hot-reload mode (backend + Flutter dev server in Chrome):

```bash
./run_app_with_server.sh
```

Android Studio users: see [README_ANDROID_STUDIO.md](README_ANDROID_STUDIO.md). Full architecture and API: [README.md](README.md).

## Troubleshooting

| Problem | Fix |
|---|---|
| `flutter not found` in Shortcut | Add Flutter bin dir to the `export PATH=` line in `scripts/apk-share.sh` |
| Phone cannot download | Same Wi-Fi? Allow incoming connections for `dart` in macOS firewall prompt |
| Wrong IP in QR (VPN/Docker) | Enter the correct LAN IP in dashboard Network card, then Reconnect |
| Port in use | `./scripts/apk-share.sh stop`, or set `APK_SHARE_PORT` |
| Dashboard shows old UI | `./scripts/apk-share.sh start --rebuild` |
| Anything else | Read `.run_logs/server.log` |
