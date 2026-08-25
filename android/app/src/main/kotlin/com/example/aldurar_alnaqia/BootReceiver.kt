package com.example.aldurar_alnaqia

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/** Restarts the prayer notification service after a device reboot. */
class BootReceiver : BroadcastReceiver() {

  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
    if (PrayerNotificationService.isRunning()) return
    val enabled = PrayerNotificationService.prefs(context)
        .getBoolean("flutter.prayer_foreground_enabled", false)
    if (!enabled) return
    ContextCompat.startForegroundService(
        context, Intent(context, PrayerNotificationService::class.java))
  }
}
