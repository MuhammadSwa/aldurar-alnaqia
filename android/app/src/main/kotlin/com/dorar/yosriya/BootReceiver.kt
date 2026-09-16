package com.dorar.yosriya

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Restarts or refreshes the prayer notification service after device reboot,
 * system time changes, or timezone updates.
 *
 * Note: a force-stop by the user clears scheduled alarms until the app is
 * opened again (expected Android behavior — nothing to do here). Exact-alarm
 * denials are handled by falling back to inexact wakeups in
 * [PrayerNotificationService.scheduleNextWakeup].
 */
class BootReceiver : BroadcastReceiver() {

  companion object {
    private const val TAG = "PrayerBootReceiver"
  }

  override fun onReceive(context: Context, intent: Intent) {
    val action = intent.action ?: return
    when (action) {
      Intent.ACTION_BOOT_COMPLETED,
      Intent.ACTION_TIME_CHANGED,
      Intent.ACTION_TIMEZONE_CHANGED,
      "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED" -> {
        val enabled = PrayerNotificationService.prefs(context)
            .getBoolean("flutter.prayer_foreground_enabled", false)
        if (!enabled) return

        if (PrayerNotificationService.isRunning()) {
          PrayerNotificationService.refreshIfRunning()
        } else {
          try {
            ContextCompat.startForegroundService(
                context, Intent(context, PrayerNotificationService::class.java))
          } catch (e: Exception) {
            // Foreground-service starts can fail (background-start limits,
            // missing permissions). Log instead of swallowing so the failure
            // is visible in crash reporting / logcat.
            Log.w(TAG, "Failed to restart prayer service on $action", e)
          }
        }
      }
    }
  }
}
