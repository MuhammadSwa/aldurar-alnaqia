package com.dorar.yosriya

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * Restarts or refreshes the prayer notification service after device reboot,
 * system time changes, or timezone updates.
 */
class BootReceiver : BroadcastReceiver() {

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
          } catch (_: Exception) {}
        }
      }
    }
  }
}
