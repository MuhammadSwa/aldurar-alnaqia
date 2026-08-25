package com.example.aldurar_alnaqia

import android.content.Intent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI and bridges it to the native prayer-notification
 * service:
 *
 *  - `app/prayer_notification` channel: start / stop / refresh / dartReady.
 *  - Notification taps launch this activity with [EXTRA_ROUTE]; the route is
 *    forwarded to Flutter via the `openRoute` channel method (buffered until
 *    the Dart handler is registered).
 */
class MainActivity : AudioServiceActivity() {

  companion object {
    const val EXTRA_ROUTE = "route"
    private const val CHANNEL_NAME = "app/prayer_notification"

    @Volatile private var pendingRoute: String? = null
    @Volatile private var channel: MethodChannel? = null
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
    ch.setMethodCallHandler { call, result ->
      when (call.method) {
        "start" -> {
          val intent = Intent(this, PrayerNotificationService::class.java)
          androidx.core.content.ContextCompat.startForegroundService(this, intent)
          result.success(null)
        }
        "stop" -> {
          // App UI is in the foreground here, so a plain stop is allowed.
          stopService(Intent(this, PrayerNotificationService::class.java))
          result.success(null)
        }
        "refresh" -> {
          // Re-read config JSON (Dart already rewrote it before calling).
          PrayerNotificationService.refreshIfRunning()
          result.success(null)
        }
        "isNotificationPosted" ->
            result.success(PrayerNotificationService.isNotificationPosted())
        "dartReady" -> {
          pendingRoute?.let { r ->
            pendingRoute = null
            ch.invokeMethod("openRoute", r)
          }
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
    channel = ch
    // NOTE: never null out `intent` here — FlutterActivity reads it later
    // (shouldRestoreAndSaveState) and crashes on a null intent.
    intent?.getStringExtra(EXTRA_ROUTE)?.let { pendingRoute = it }
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    deliverRoute(intent.getStringExtra(EXTRA_ROUTE))
  }

  private fun deliverRoute(route: String?) {
    if (route.isNullOrEmpty()) return
    val ch = channel
    if (ch != null) {
      ch.invokeMethod("openRoute", route)
    } else {
      pendingRoute = route
    }
  }
}
