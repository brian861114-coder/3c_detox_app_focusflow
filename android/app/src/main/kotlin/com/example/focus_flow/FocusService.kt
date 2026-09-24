package com.example.focus_flow

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

class FocusService : Service() {
    companion object {
        const val ACTION_STOP = "STOP_SERVICE"
        const val EXTRA_BLOCKED_APPS = "blockedApps"
        const val EXTRA_REMAINING_SECONDS = "remainingSeconds"
        const val EXTRA_RESTING = "resting"

        private const val CHANNEL_ID = "FocusFlowChannel"
        private const val NOTIFICATION_ID = 1
        private const val PREFS = "focus_service"

        // If Flutter has not extended or stopped the session by then, stop on our own
        // so a killed app never leaves the blocker running forever.
        private const val SELF_STOP_GRACE_MS = 15_000L

        @Volatile
        var isRunning = false
            private set
    }

    private val handler = Handler(Looper.getMainLooper())
    private var blockedApps: Set<String> = emptySet()
    private var endAtMillis = 0L
    private var resting = false
    private var lastForegroundApp: String? = null
    private var lastEventQueryMillis = 0L

    private val checkRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return
            val now = System.currentTimeMillis()
            if (now > endAtMillis + SELF_STOP_GRACE_MS) {
                stopFocusService()
                return
            }
            if (!resting) checkForegroundApp(now)
            notificationManager()?.notify(NOTIFICATION_ID, buildNotification(now))
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val type = if (Build.VERSION.SDK_INT >= 34) ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
        ServiceCompat.startForeground(this, NOTIFICATION_ID, buildNotification(System.currentTimeMillis()), type)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopFocusService()
            return START_NOT_STICKY
        }

        val apps = intent?.getStringArrayListExtra(EXTRA_BLOCKED_APPS)
        if (apps != null) {
            val seconds = intent.getIntExtra(EXTRA_REMAINING_SECONDS, 0)
            applyState(apps.toSet(), System.currentTimeMillis() + seconds * 1000L, intent.getBooleanExtra(EXTRA_RESTING, false))
            saveState()
        } else if (!restoreState()) {
            // Restarted by the system (START_STICKY) after the session already ended.
            stopFocusService()
            return START_NOT_STICKY
        }

        if (!isRunning) {
            isRunning = true
            handler.post(checkRunnable)
        }
        return START_STICKY
    }

    private fun applyState(apps: Set<String>, endAt: Long, isResting: Boolean) {
        blockedApps = apps
        endAtMillis = endAt
        resting = isResting
    }

    private fun saveState() {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putStringSet(EXTRA_BLOCKED_APPS, blockedApps)
            .putLong("endAtMillis", endAtMillis)
            .putBoolean(EXTRA_RESTING, resting)
            .apply()
    }

    private fun restoreState(): Boolean {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val endAt = prefs.getLong("endAtMillis", 0L)
        if (endAt <= System.currentTimeMillis()) return false
        applyState(prefs.getStringSet(EXTRA_BLOCKED_APPS, emptySet()) ?: emptySet(), endAt, prefs.getBoolean(EXTRA_RESTING, false))
        return true
    }

    private fun clearState() {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    private fun checkForegroundApp(now: Long) {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return
        // Track the latest foreground app across checks, so staying inside a
        // blocked app (which emits no new events) is still detected.
        // Small overlap so late-reported events are not missed; replaying them is harmless.
        val begin = if (lastEventQueryMillis == 0L) now - 10_000 else lastEventQueryMillis - 2_000
        val usageEvents = usm.queryEvents(begin, now)
        lastEventQueryMillis = now
        val event = UsageEvents.Event()
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            @Suppress("DEPRECATION")
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                lastForegroundApp = event.packageName
            }
        }

        val current = lastForegroundApp ?: return
        if (current != packageName && current in blockedApps) {
            startActivity(Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            })
        }
    }

    private fun buildNotification(now: Long): Notification {
        val remaining = ((endAtMillis - now).coerceAtLeast(0L) + 999) / 1000
        val timeString = String.format("%02d:%02d", remaining / 60, remaining % 60)
        val contentText = if (resting) "休息中  剩下 $timeString" else "專注進行中  剩下 $timeString"
        val openApp = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Focus Mode Active")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun notificationManager(): NotificationManager? = getSystemService(NotificationManager::class.java)

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Focus Flow Service", NotificationManager.IMPORTANCE_LOW)
            notificationManager()?.createNotificationChannel(channel)
        }
    }

    private fun stopFocusService() {
        isRunning = false
        handler.removeCallbacks(checkRunnable)
        clearState()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacks(checkRunnable)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
