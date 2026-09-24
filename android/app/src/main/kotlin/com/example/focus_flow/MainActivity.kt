package com.example.focus_flow

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "focus_flow/native"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 13+: the focus countdown notification needs runtime permission.
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 0)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "requestUsageStatsPermission" -> openSettings(result, Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                "requestOverlayPermission" -> openSettings(
                    result,
                    Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")),
                    Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                )
                "requestBatteryOptimizationPermission" -> openSettings(result, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                "getInstalledApps" -> {
                    val pm = packageManager
                    val appList = pm.getInstalledApplications(0)
                        .filter { it.packageName != packageName && pm.getLaunchIntentForPackage(it.packageName) != null }
                        .map { mapOf("name" to pm.getApplicationLabel(it).toString(), "packageName" to it.packageName) }
                    result.success(appList)
                }
                "startService" -> {
                    val apps = call.argument<List<String>>("blockedApps") ?: emptyList()
                    val serviceIntent = Intent(this, FocusService::class.java).apply {
                        putStringArrayListExtra(FocusService.EXTRA_BLOCKED_APPS, ArrayList(apps))
                        putExtra(FocusService.EXTRA_REMAINING_SECONDS, call.argument<Int>("remainingSeconds") ?: 0)
                        putExtra(FocusService.EXTRA_RESTING, call.argument<Boolean>("resting") ?: false)
                    }
                    try {
                        // Updating an already-running foreground service is allowed from the
                        // background; starting a new one there may be refused (Android 12+).
                        if (FocusService.isRunning || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                            startService(serviceIntent)
                        } else {
                            startForegroundService(serviceIntent)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        Log.w("FocusFlow", "Could not start focus service", e)
                        result.error("SERVICE_START_FAILED", e.message, null)
                    }
                }
                "stopService" -> {
                    if (FocusService.isRunning) {
                        startService(Intent(this, FocusService::class.java).setAction(FocusService.ACTION_STOP))
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Opens the first settings screen this device supports. */
    private fun openSettings(result: MethodChannel.Result, vararg intents: Intent) {
        for (intent in intents) {
            try {
                startActivity(intent)
                result.success(null)
                return
            } catch (e: Exception) {
                Log.w("FocusFlow", "Settings screen unavailable: ${intent.action}", e)
            }
        }
        result.error("SETTINGS_UNAVAILABLE", "No settings screen could be opened", null)
    }
}
