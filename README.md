# APK LAN Share

A Flutter **web** dashboard that runs locally on your laptop, stages Android
`.apk` files through a tiny companion server, and hands out a **QR code** so
any device on the same Wi-Fi can download them instantly.

```
┌────────────────────┐   HTTP POST /upload    ┌──────────────────────┐
│  Flutter Web UI    │ ─────────────────────▶ │  Companion backend   │
│  (browser sandbox) │                        │  Dart + package:shelf│
│  drop zone → QR    │ ◀───────────────────── │  saves .apk to disk  │
└────────────────────┘   GET /info, /download └──────────┬───────────┘
                                                         │  LAN
                              ┌──────────────────────────▼──────────┐
                              │ Phone / tablet scans QR → downloads │
                              │ http://192.168.x.x:8080/download/…  │
                              └─────────────────────────────────────┘
```

> **Why a companion server?** Flutter Web runs in the browser sandbox: it can
> read a picked file's bytes but it cannot open a listening socket or serve
> files from disk. The Dart backend does the networking; the UI drives it.

---

## 1. Folder layout

```
apk-lan-share/
├── pubspec.yaml                  # Flutter app dependencies
├── analysis_options.yaml
├── README.md
│
├── lib/
│   ├── main.dart                 # entry point
│   ├── app.dart                  # MaterialApp + light/dark theming
│   ├── theme/
│   │   └── app_theme.dart        # Material 3 design system (seed: indigo)
│   ├── models/
│   │   └── share_models.dart     # ShareStage, HostedFile, BackendInfo, LogEntry
│   ├── services/
│   │   └── share_api.dart        # /info client + XHR upload with byte progress
│   ├── state/
│   │   └── share_controller.dart # ChangeNotifier: connection, staging, logs
│   ├── util/
│   │   └── formatters.dart       # formatBytes, clock formatting
│   ├── widgets/
│   │   ├── panel_card.dart       # card shell + connection badge
│   │   ├── dashed_border.dart    # CustomPainter dashed drop-zone border
│   │   ├── drop_zone.dart        # drag & drop + browse + progress/success
│   │   ├── connection_panel.dart # LAN IP / port fields + reconnect + status
│   │   ├── qr_share_card.dart    # centered QR + plain URL + copy button
│   │   └── activity_log.dart     # scrolling event logger
│   └── pages/
│       └── dashboard_page.dart   # responsive two-column dashboard
│
├── test/
│   └── widget_test.dart          # model + formatter unit tests
│
├── web/                          # Flutter web shell (index.html, manifest)
│
└── backend/                      # standalone companion server (own package)
    ├── pubspec.yaml              # shelf + mime + path
    ├── bin/
    │   └── server.dart           # CLI: args, banner, graceful shutdown
    ├── lib/
    │   └── apk_share_server.dart # routing, CORS, upload, download, IP detect
    └── public/                   # ← staged .apk files land here (auto-created)
```

## 2. Dependencies

**Flutter app (`pubspec.yaml`)**

| Package | Version | Purpose |
|---|---|---|
| `qr_flutter` | ^4.1.0 | QR rendering (pure CustomPainter, web-safe) |
| `file_picker` | ^13.1.0 | "Browse…" picker filtered to `.apk` |
| `desktop_drop` | ^0.8.4 | HTML5 drag-and-drop on web, native on desktop |
| `http` | ^1.6.0 | `GET /info` health check |
| `web` | ^1.1.1 | `XMLHttpRequest` interop → **real upload progress** |
| `flutter_lints` | ^6.0.0 (dev) | lint rules |

**Companion server (`backend/pubspec.yaml`)**

| Package | Purpose |
|---|---|
| `shelf` | HTTP routing + `shelf_io` server |
| `mime` | content types for the built Flutter assets |
| `path` | safe path joining / traversal guards |

State management is deliberately dependency-free: one `ChangeNotifier`
(`ShareController`) + `ListenableBuilder`.

## 3. API surface (companion server)

| Method | Route | Description |
|---|---|---|
| `GET` | `/info` | `{ lanIp, port, baseUrl, storageDir, files[] }` |
| `POST` | `/upload?name=<file>.apk` | raw body → staged file (returns JSON) |
| `GET`/`HEAD` | `/download/<file>.apk` | streams the APK, `Content-Disposition: attachment` |
| `GET` | `/` | the built Flutter dashboard (when `--ui` is set) |
| `OPTIONS` | `*` | CORS preflight (`Access-Control-Allow-Origin: *`) |

Filenames are sanitized server-side (basename only, `[A-Za-z0-9._-]`,
`.apk` required) and path traversal (`../`) is rejected. Uploads stream to a
`.part` file and are renamed only after a complete, verified write.

---

## 4. Running it locally

### Prerequisites
- Flutter SDK (3.24+; tested on 3.47 / Dart 3.13)
- Nothing else — the backend is plain Dart, **no Node.js required**

### Option A — one port, production-style (recommended)

```bash
cd "apk-lan-share"

# 1. Build the web dashboard once
flutter pub get
flutter build web --release

# 2. Start the companion server (auto-detects build/web and your LAN IP)
cd backend
dart pub get
dart run bin/server.dart --port 8080
```

Open **<http://127.0.0.1:8080>** — the dashboard and the download endpoint
share port 8080. The banner prints your LAN URL:

```
✓ Listening on 0.0.0.0:8080
✓ LAN address   http://192.168.0.21:8080
✓ Dashboard     http://127.0.0.1:8080  (built Flutter web)
✓ CORS          enabled (Access-Control-Allow-Origin: *)
```

### Option B — dev mode with hot reload

```bash
# Terminal 1 — backend
cd apk-lan-share/backend && dart pub get
dart run bin/server.dart --port 8080

# Terminal 2 — Flutter web dev server
cd apk-lan-share && flutter pub get
flutter run -d web-server --web-port 5000 --web-hostname 127.0.0.1
```

Open <http://localhost:5000>. The UI talks to the backend on `:8080`
across origins — CORS is already handled by the server.

### Using the dashboard

1. The badge in the top-right should read **Online · \<lan-ip\>:8080**
   (auto-detected). If it shows *Offline*, the Network card prints the exact
   command to start the server, plus a copy button.
2. **Drop an `.apk` onto the dashed box** (or click to browse).
   The box turns into a progress bar, then a green success state.
3. The right-hand card shows the **QR code** and the plain URL underneath —
   scan it from any device on the same Wi-Fi, or type the URL manually.
4. The **Activity** panel logs every event (staging, connection, URLs).

Files persist in `backend/public/` and are restored automatically on the next
start (the dashboard re-shows the most recent one).

### Server options

```
dart run bin/server.dart [options]
  --port <n>       port to listen on (default 8080)
  --host <addr>    interface to bind (default 0.0.0.0 = whole LAN)
  --dir <path>     staging directory for APKs (default ./public)
  --ui <path>      serve a built Flutter web app (default: auto-detects build/web)
  --no-ui          API only, no dashboard
  -h, --help
```

Examples:

```bash
dart run bin/server.dart --port 9090 --dir ~/Public/apks
dart run bin/server.dart --no-ui          # API only; run flutter run separately
```

### Verify your setup

```bash
# backend reachable?
curl http://127.0.0.1:8080/info

# manual upload / download round-trip
curl -X POST "http://127.0.0.1:8080/upload?name=app.apk" \
     -H "Content-Type: application/octet-stream" --data-binary @app.apk
curl -OJ "http://127.0.0.1:8080/download/app.apk"
```

### Tests & checks

```bash
flutter analyze      # app (includes backend/)
flutter test         # model + formatter tests
cd backend && dart analyze
```

---

## 5. Design & architecture notes

- **Material 3** throughout: `ColorScheme.fromSeed` (indigo), light/dark via
  `ThemeMode.system`, 24px card radii, `LinearProgressIndicator` staging bars,
  and a custom `CustomPainter` dashed border for the drop zone (no extra dep).
- **Responsive**: ≥1000px → two columns (drop zone + network | QR), below that
  a single stacked column. Cards cap at 1180px.
- **Real upload progress**: the browser's `fetch()` cannot report upload
  progress, so `ShareApi.uploadApk` uses `XMLHttpRequest` through
  `package:web` and listens to `upload.onprogress` — the progress bar shows
  genuine byte counts, not an animation.
- **Network detection**: browsers cannot read the machine's LAN IP reliably,
  so the **backend detects it** (interface scoring: prefers `192.168.x` >
  `10.x` > `172.16-31.x`, penalises docker/vmnet) and reports it via `/info`.
  The IP field in the Network card is auto-filled and can be overridden
  (e.g. multiple adapters / VPN).
- **Connection probing order**: `http://127.0.0.1:<port>` first (works in both
  Option A and B), then the page origin (covers a reverse-proxied setup).
- **Security posture**: LAN-only by design — bind `127.0.0.1` with
  `--host 127.0.0.1` if you don't want other devices to reach the API itself;
  filenames are sanitized; `.apk` only; 4 GB hard cap; `nosniff` +
  `no-store` headers on downloads.

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| Badge shows *Offline* | Start the backend; check the port matches (`--port`) |
| macOS firewall prompt | Allow incoming connections for `dart`/your terminal — otherwise phones can't connect |
| Wrong IP in the QR (VPN/Docker) | Type the correct LAN IP in the Network card → Reconnect |
| Port already in use | `dart run bin/server.dart --port 8081` |
| Dashboard 404 page ("dashboard not built") | `flutter build web` first, restart with `--ui build/web` |
| Phone can't download | Both devices on the same Wi-Fi; ping `http://<lan-ip>:8080` from the phone |
