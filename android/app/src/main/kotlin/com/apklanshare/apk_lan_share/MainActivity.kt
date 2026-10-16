package com.apklanshare.apk_lan_share

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openHotspotSettings" -> result.success(openHotspotSettings())
                    "startService" -> {
                        if (Build.VERSION.SDK_INT >= 33) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
                        }
                        val intent = Intent(this, ShareService::class.java)
                            .putExtra("text", call.argument<String>("text") ?: "")
                        startForegroundService(intent)
                        result.success(null)
                    }
                    "stopService" -> {
                        stopService(Intent(this, ShareService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Tries the tethering screen first, then falls back to wireless settings. */
    private fun openHotspotSettings(): Boolean {
        val attempts = listOf(
            Intent().setComponent(
                ComponentName("com.android.settings", "com.android.settings.TetherSettings")
            ),
            Intent("android.settings.TETHER_SETTINGS"),
            Intent(Settings.ACTION_WIRELESS_SETTINGS),
        )
        for (intent in attempts) {
            try {
                startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: ActivityNotFoundException) {
            } catch (_: SecurityException) {
            }
        }
        return false
    }

    companion object {
        const val CHANNEL = "apk_lan_share/native"
    }
}
