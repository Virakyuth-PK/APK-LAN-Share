# Contributing

## Project layout

```
apk-lan-share/
├── lib/                       Flutter Web dashboard
│   ├── main.dart, app.dart
│   ├── theme/app_theme.dart   glass light-blue theme
│   ├── models/                ShareStage, HostedFile, BackendInfo, LogEntry
│   ├── services/share_api.dart  /info client, XHR upload with byte progress
│   ├── state/share_controller.dart  ChangeNotifier: connection, staging, logs
│   ├── util/                  formatters, web_drop (window-level drag and drop)
│   ├── widgets/               drop zone parts, staged_files_card, qr_share_card,
│   │                          devices_card, connection_panel, activity_log, glass_card
│   └── pages/dashboard_page.dart  responsive layout
├── test/widget_test.dart      model + formatter tests
├── backend/                   companion server (own Dart package)
│   ├── bin/server.dart        CLI args, banner, shutdown
│   └── lib/
│       ├── apk_share_server.dart  routing, CORS, upload, download, IP detect
│       ├── apk_meta.dart          binary AndroidManifest + icon + SHA-256
│       ├── download_page.dart     phone HTML pages
│       └── download_tracker.dart  in-memory download records
├── scripts/apk-share.sh       start / stop / status (used by Apple Shortcuts)
└── run_app_with_server.sh     dev mode: backend + flutter run with hot reload
```

## Dependencies

App: `qr_flutter`, `file_picker`, `http`, `web`. Server: `shelf`, `mime`, `path`, `archive`, `crypto`.
State management is one `ChangeNotifier` plus `ListenableBuilder`. No extra packages.

## Dev mode (hot reload)

```bash
./run_app_with_server.sh
```

Starts the backend on `:8080` (API only) and `flutter run -d chrome` on `http://127.0.0.1:5000`. Ctrl+C stops both. Logs in `.run_logs/`. CORS is enabled so the two origins work together.

Manual version, two terminals:

```bash
cd backend && dart pub get && dart run bin/server.dart --no-ui
flutter pub get && flutter run -d web-server --web-port 5000 --web-hostname 127.0.0.1
```

UI changes need `./scripts/apk-share.sh start --rebuild` to show in the one-port mode.

## Android Studio

`.idea/` is git-ignored, so create these run configurations yourself:

1. Dart Command Line App "Start Backend Server": `backend/bin/server.dart`, args `--port 8080 --no-ui`, working dir `backend/`.
2. Flutter "Flutter Web (Chrome)": `lib/main.dart`, additional args `-d chrome --web-port 5000 --web-hostname 127.0.0.1`.
3. Compound "Run App With Server": both of the above. Stop button stops both.

## Checks

```bash
flutter analyze
flutter test
cd backend && dart analyze
```

Run all three before a PR. Use conventional commit prefixes (`feat:`, `fix:`, `docs:`).
