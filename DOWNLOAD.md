# Download

Prebuilt Android APKs of **APK LAN Share** v1.0.0, one per CPU architecture (split APKs, smaller than a universal build).

| Your device | File | Size |
|---|---|---|
| Most phones since ~2017 (64-bit ARM) | [apk-lan-share-1.0.0-arm64-v8a.apk](releases/apk-lan-share-1.0.0-arm64-v8a.apk) | 17.3 MB |
| Older phones (32-bit ARM) | [apk-lan-share-1.0.0-armeabi-v7a.apk](releases/apk-lan-share-1.0.0-armeabi-v7a.apk) | 14.9 MB |
| Emulator / Intel Chromebook (x86_64) | [apk-lan-share-1.0.0-x86_64.apk](releases/apk-lan-share-1.0.0-x86_64.apk) | 18.7 MB |

Not sure which one? Pick **arm64-v8a**. Check with `adb shell getprop ro.product.cpu.abi`.

Requires Android 7.0 (API 24) or newer.

## Install

1. Download the file for your device (on GitHub, open the file and press **Download raw file**).
2. Open it on the phone. Allow **Install unknown apps** for your browser or file manager if Android asks.
3. Open **APK LAN Share**. See [README.md](README.md#android-app) for usage.

Or from a computer with USB debugging:

```bash
adb install releases/apk-lan-share-1.0.0-arm64-v8a.apk
```

## Checksums (SHA-256)

```
326ca0abb48a07117e36f55cf437211ebefef293cbada00daedbcd7ec66206d8  apk-lan-share-1.0.0-arm64-v8a.apk
5c5e42bbb4b1f96233b3f4cb8da263f1c55b81d26d735140f4c63ffb7ae91656  apk-lan-share-1.0.0-armeabi-v7a.apk
64f218d843917c2b19b63d4b138216984e6d54658e3d2db02e538ae486030a36  apk-lan-share-1.0.0-x86_64.apk
```

Verify: `shasum -a 256 apk-lan-share-1.0.0-arm64-v8a.apk`

## Note

These builds are signed with the Android debug key, not a Play Store release key. Fine for sideloading and testing. A new build signed with a different key cannot update over this one: uninstall first.

## Rebuild

```bash
flutter build apk --release --split-per-abi
# output: build/app/outputs/flutter-apk/app-<abi>-release.apk
```
