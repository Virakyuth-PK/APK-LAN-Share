# Android Studio Integration

Right-click any `.apk` in Android Studio and send it straight to APK LAN Share.
The server starts automatically if it isn't running, the APK is staged, and the
dashboard opens.

Android Studio can't add items to the **Open In** menu, so this uses
**External Tools**, which appear under **right-click → External Tools**.

## 1. Set up the External Tool

1. Open **Android Studio → Settings** (`⌘,`) → **Tools → External Tools**.
2. Click **+** and fill in:

   | Field             | Value                                                     |
   | ----------------- | --------------------------------------------------------- |
   | Name              | `Start APK Share`                                         |
   | Program           | `/path/to/apk-lan-share/scripts/apk-share.sh`             |
   | Arguments         | `share "$FilePath$"`                                      |
   | Working directory | `/path/to/apk-lan-share`                                  |

   Replace `/path/to/apk-lan-share` with where you cloned this repo.
   Keep the quotes around `$FilePath$`, because paths often contain spaces.

3. Optional: tick **Open console** to see the script's output.
4. Click **OK**, then **Apply**.

If Android Studio can't execute the script directly, set **Program** to
`/bin/bash` and **Arguments** to:

```
"/path/to/apk-lan-share/scripts/apk-share.sh" share "$FilePath$"
```

## 2. Make the script executable (once)

```bash
chmod +x scripts/apk-share.sh
```

## 3. Use it

In the **Project** view, right-click an `.apk` file (for example
`build/app/outputs/apk/dev/release/app-dev-arm64-v8a-release.apk`) and choose
**External Tools → Start APK Share**.

Optional shortcut: **Settings → Keymap → External Tools → Start APK Share**.

## How it works

`apk-share.sh share <apk>`:

1. Checks the file exists and ends in `.apk`.
2. Starts the server if it isn't running (building the web dashboard on first run).
3. Uploads the APK with `POST /upload?name=<file>.apk` (raw body).
4. Shows a notification and opens the dashboard.

You can run it from Terminal too:

```bash
scripts/apk-share.sh share /path/to/app-release.apk
```

Other commands: `start`, `stop`, `restart`, `status`, and
`start --rebuild` to rebuild the web dashboard.

## Troubleshooting

| Problem | Fix |
| ------- | --- |
| `Permission denied` | Run `chmod +x scripts/apk-share.sh`. |
| `dart not found` / `flutter not found` | The script adds common Flutter paths (`~/fvm/default/bin`, `~/development/flutter/bin`, `~/flutter/bin`, Homebrew). Add yours to the `PATH` line near the top of the script. |
| `Not an APK` | Only `.apk` files are accepted (not `.aab`). |
| `Upload failed: ...` | Read the message. Details are in `.run_logs/server.log`. |
| Port already in use | Set another port: `APK_SHARE_PORT=8090`. |
