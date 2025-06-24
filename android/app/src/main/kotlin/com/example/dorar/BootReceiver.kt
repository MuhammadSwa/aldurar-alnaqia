// android/app/src/main/kotlin/com/example/dorar/BootReceiver.kt
// Make sure 'com.example.dorar' is your actual package name
package com.example.aldurar_alnaqia// <-- IMPORTANT: Replace with your app's package name

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
// No need to import FlutterBackgroundServicePlugin if you're not calling its static methods directly here.
// The service class itself is what you need to start.

class BootReceiver : BroadcastReceiver() {

    companion object {
        // Define constants for SharedPreferences, ensure they match your Dart code
        // Using the same constants as defined in your Dart service
        const val PREFS_NAME = "PrayerAppPrefs"
        const val NOTIFICATION_ENABLED_KEY = "prayer_notification_enabled"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        // Check for various boot completed actions
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.LOCKED_BOOT_COMPLETED") { // For Direct Boot aware apps

            val sharedPreferences: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val notificationsWereEnabled = sharedPreferences.getBoolean(NOTIFICATION_ENABLED_KEY, false)

            if (notificationsWereEnabled) {
                // The flutter_background_service plugin will handle its own Dart initialization
                // when its Android Service component is started.
                // We just need to start that Android Service.

                // Create an Intent for the plugin's BackgroundService
                val serviceIntent = Intent(context, id.flutter.flutter_background_service.BackgroundService::class.java)

                // Start the service appropriately based on Android version
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }
}
