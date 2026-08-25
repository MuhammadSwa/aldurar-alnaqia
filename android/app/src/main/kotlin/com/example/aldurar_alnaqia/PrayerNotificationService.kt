package com.example.aldurar_alnaqia

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.batoulapps.adhan2.CalculationMethod
import com.batoulapps.adhan2.CalculationParameters
import com.batoulapps.adhan2.Coordinates
import com.batoulapps.adhan2.HighLatitudeRule
import com.batoulapps.adhan2.Madhab
import com.batoulapps.adhan2.PrayerTimes
import com.batoulapps.adhan2.data.DateComponents
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.datetime.Instant
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.plus
import kotlinx.datetime.toInstant
import kotlinx.datetime.toLocalDateTime
import org.json.JSONObject

/**
 * Native foreground service showing a persistent prayer-times notification
 * with a system-rendered countdown for the next prayer.
 *
 * Runs entirely without the Flutter engine: config is read from the
 * SharedPreferences file written by Dart (key `flutter.prayer_native_config`),
 * and Dart wakes this service through the `app/prayer_notification`
 * method channel handled by [MainActivity].
 *
 * Battery profile: the visible countdown is rendered by SystemUI
 * (chronometer), so this process only does work at prayer boundaries and
 * just after midnight (~7 times a day).
 */
class PrayerNotificationService : Service() {

  companion object {
    const val CHANNEL_ID = "prayer_timing_channel"
    const val NOTIFICATION_ID = 988

    private const val PREFS_FILE = "FlutterSharedPreferences"
    private const val KEY_CONFIG = "flutter.prayer_native_config"

    /** Retry cadence while no location has been configured yet. */
    private val NO_LOCATION_RETRY_MS = 15 * 60 * 1000L

    @Volatile
    private var running: PrayerNotificationService? = null

    /** True only once the notification has actually been posted. */
    @Volatile
    private var notificationPosted: Boolean = false

    /** Re-post the notification with fresh settings; no-op if not running. */
    fun refreshIfRunning() {
      running?.requestRefresh()
    }

    fun isRunning(): Boolean = running != null

    fun isNotificationPosted(): Boolean = notificationPosted

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
  }

  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
  private var updateJob: Job? = null

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    ensureChannel()
    running = this
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    // Post something immediately so startForeground() satisfies its deadline.
    startForeground(
        NOTIFICATION_ID,
        buildNotification(content = "جارٍ التحديث...", bigTextHtml = "جارٍ التحديث...",
            countdownTargetMs = null))
    notificationPosted = true
    requestRefresh()
    return START_STICKY
  }

  override fun onDestroy() {
    updateJob?.cancel()
    scope.cancel()
    if (running === this) running = null
    notificationPosted = false
    // Remove the notification too: an in-flight update coroutine may have
    // posted it again between stopService() and this point.
    getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
    super.onDestroy()
  }

  fun requestRefresh() {
    updateJob?.cancel()
    updateJob = scope.launch { runUpdate() }
  }

  // -------------------------------------------------------------------------
  // Computation + scheduling loop
  // -------------------------------------------------------------------------

  private suspend fun runUpdate() {
    val cfg = readConfig(this)

    if (cfg == null || cfg.lat == 0.0 || cfg.lng == 0.0) {
      postNotification("الرجاء ضبط الموقع لحساب المواقيت",
          "الرجاء ضبط الموقع لحساب المواقيت", null)
      scheduleNext(NO_LOCATION_RETRY_MS)
      return
    }

    val nowMs = System.currentTimeMillis()
    val zone = cfg.zone()
    val plan = computePlan(cfg, zone, nowMs)

    if (plan == null) {
      postNotification("تعذّر حساب المواقيت", "تعذّر حساب المواقيت", null)
      scheduleNext(NO_LOCATION_RETRY_MS)
      return
    }

    postNotification(
        content = "الصلاة القادمة: ${plan.nextName}",
        bigTextHtml = plan.rows.joinToString("<br>") +
            "<br><b>${plan.nextName} بعد ${formatCountdown(plan.nextAtMs - nowMs)}</b>",
        countdownTargetMs = plan.nextAtMs)

    scheduleNext(delayUntilNextWake(nowMs, zone, plan.nextAtMs))
  }

  private fun scheduleNext(delayMs: Long) {
    updateJob?.cancel()
    updateJob = scope.launch {
      delay(delayMs.coerceAtLeast(2000))
      runUpdate()
    }
  }

  /**
   * Next Dart-side wakeup: just past the next prayer boundary, or just past
   * local midnight when today's schedule goes stale.
   */
  private fun delayUntilNextWake(nowMs: Long, zone: TimeZone, nextPrayerAtMs: Long): Long {
    val nowDate = Instant.fromEpochMilliseconds(nowMs).toLocalDateTime(zone).date
    val nextMidnightMs =
        (nowDate.plus(1, kotlinx.datetime.DateTimeUnit.DAY)).atStartOfDayIn(zone)
            .toEpochMilliseconds()
    return if (nextPrayerAtMs >= nextMidnightMs) {
      nextMidnightMs - nowMs + 5000
    } else {
      nextPrayerAtMs - nowMs + 2000
    }
  }

  // -------------------------------------------------------------------------
  // Notification
  // -------------------------------------------------------------------------

  private fun postNotification(content: String, bigTextHtml: String, countdownTargetMs: Long?) {
    // Never post after the service has been asked to stop.
    if (running !== this) return
    val nm = getSystemService(NotificationManager::class.java)
    nm?.notify(NOTIFICATION_ID,
        buildNotification(content, bigTextHtml, countdownTargetMs))
    notificationPosted = true
  }

  private fun buildNotification(
    content: String,
    bigTextHtml: String,
    countdownTargetMs: Long?
  ): Notification {
    val openIntent = Intent(this, MainActivity::class.java).apply {
      action = "$packageName.OPEN_TIMINGS"
      putExtra(MainActivity.EXTRA_ROUTE, "/timings")
      addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }
    val pendingIntent = PendingIntent.getActivity(
        this, 0, openIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    // \u200F (RLM) makes the first strong character RTL so the text is
    // right-aligned even on English-locale devices; \u202B...\u202C keeps
    // mixed Arabic/time runs in visual RTL order.
    val html = "\u200F\u202B$bigTextHtml\u202C"

    return NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(R.drawable.ic_stat_prayer)
        .setColor(0xFF2E7D32.toInt())
        .setOngoing(true)
        .setOnlyAlertOnce(true)
        .setAutoCancel(false)
        .setSilent(true)
        .setShowWhen(countdownTargetMs != null)
        .setContentTitle("\u200F\u202Bمواقيت الصلاة\u202C")
        .setContentText("\u200F\u202B$content\u202C")
        .setStyle(
            NotificationCompat.BigTextStyle()
                .bigText(android.text.Html.fromHtml(html))
                .setBigContentTitle("\u200F\u202Bمواقيت الصلاة\u202C")
                .setSummaryText("\u200F\u202B$content\u202C"))
        .apply {
          if (countdownTargetMs != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            setUsesChronometer(true)
            setChronometerCountDown(true)
            setWhen(countdownTargetMs)
          }
        }
        .setContentIntent(pendingIntent)
        .build()
  }

  private fun ensureChannel() {
    val nm = getSystemService(NotificationManager::class.java) ?: return
    val channel = NotificationChannel(CHANNEL_ID, "مواقيت الصلاة",
        NotificationManager.IMPORTANCE_LOW).apply {
      description = "إشعار دائم يعرض مواقيت الصلاة والعد التنازلي للصلاة التالية"
      enableVibration(false)
      enableLights(false)
      setShowBadge(false)
      setSound(null, null)
    }
    nm.createNotificationChannel(channel)
  }

  // -------------------------------------------------------------------------
  // Config (written as JSON by the Flutter side)
 // -------------------------------------------------------------------------

  data class Config(
    val lat: Double,
    val lng: Double,
    val method: String,
    val asrCalculation: String,
    val highLatitudeRule: String,
    val timezone: String
  ) {
    fun zone(): TimeZone =
        try { TimeZone.of(timezone) } catch (_: Exception) { TimeZone.currentSystemDefault() }
  }

  private fun readConfig(context: Context): Config? {
    val raw = prefs(context).getString(KEY_CONFIG, null) ?: return null
    return try {
      val o = JSONObject(raw)
      Config(
          lat = o.getDouble("lat"),
          lng = o.getDouble("lng"),
          method = o.optString("method", "egyptian"),
          asrCalculation = o.optString("asrCalculation", "shafi"),
          highLatitudeRule = o.optString("highLatitudeRule", "middle_of_night"),
          timezone = o.optString("timezone", ""))
    } catch (_: Exception) {
      null
    }
  }

  private class DayPlan(val rows: List<String>, val nextName: String, val nextAtMs: Long)

  private fun computePlan(cfg: Config, zone: TimeZone, nowMs: Long): DayPlan? {
    val params = buildParams(cfg.method, cfg.asrCalculation, cfg.highLatitudeRule, cfg.lat)
    val coordinates = Coordinates(cfg.lat, cfg.lng)
    val now = Instant.fromEpochMilliseconds(nowMs).toLocalDateTime(zone)

    val fmt = SimpleDateFormat("h:mm", Locale.US).apply {
      timeZone = java.util.TimeZone.getTimeZone(zone.id)
    }

    fun rowsFor(times: List<Pair<String, Long>>, nextName: String): List<String> =
        times.map { (name, ms) ->
          val formatted = "${fmt.format(Date(ms))} ${if (hourOf(ms, zone) < 12) "ص" else "م"}"
          if (name == nextName)
            "<b><font color=\"#2e7d32\">$name $formatted</font></b>"
          else "$name $formatted"
        }

    val todayTimes = prayerTimesList(coordinates, params, now.date, zone)
        ?: return null
    val next = todayTimes.firstOrNull { it.second > nowMs }

    if (next != null) {
      return DayPlan(rowsFor(todayTimes, next.first), next.first, next.second)
    }

    // After Isha: show tomorrow's Fajr as the upcoming prayer.
    val tomorrow = now.date.plus(1, kotlinx.datetime.DateTimeUnit.DAY)
    val tomorrowFajr = prayerTimesList(coordinates, params, tomorrow, zone)
        ?.firstOrNull()?.second ?: return null
    return DayPlan(rowsFor(todayTimes, "الفجر"), "الفجر", tomorrowFajr)
  }

  private fun hourOf(ms: Long, zone: TimeZone): Int =
      Instant.fromEpochMilliseconds(ms).toLocalDateTime(zone).hour

  /** "01:23:45" / "23:45" style remaining time. */
  private fun formatCountdown(diffMs: Long): String {
    val total = (diffMs / 1000).coerceAtLeast(0)
    val h = total / 3600
    val m = (total % 3600) / 60
    val s = total % 60
    return if (h > 0) String.format(Locale.US, "%02d:%02d:%02d", h, m, s)
    else String.format(Locale.US, "%02d:%02d", m, s)
  }

  /** Six entries (Arabic name, epoch ms) for the given date, or null on failure. */
  private fun prayerTimesList(
    coordinates: Coordinates,
    params: CalculationParameters,
    date: kotlinx.datetime.LocalDate,
    zone: TimeZone
  ): List<Pair<String, Long>>? {
    return try {
      val pt = PrayerTimes(coordinates, DateComponents(date.year, date.monthNumber,
          date.dayOfMonth), params)
      listOf(
          "الفجر" to pt.fajr.toEpochMilliseconds(),
          "الشروق" to pt.sunrise.toEpochMilliseconds(),
          "الظهر" to pt.dhuhr.toEpochMilliseconds(),
          "العصر" to pt.asr.toEpochMilliseconds(),
          "المغرب" to pt.maghrib.toEpochMilliseconds(),
          "العشاء" to pt.isha.toEpochMilliseconds())
    } catch (_: Exception) {
      null
    }
  }

  private fun buildParams(
    method: String,
    asrCalculation: String,
    highLatitudeRule: String,
    lat: Double
  ): CalculationParameters {
    var params: CalculationParameters = when (method) {
      "egyptian" -> CalculationMethod.EGYPTIAN.parameters
      "karachi" -> CalculationMethod.KARACHI.parameters
      "muslim_world_league" -> CalculationMethod.MUSLIM_WORLD_LEAGUE.parameters
      "dubai" -> CalculationMethod.DUBAI.parameters
      "qatar" -> CalculationMethod.QATAR.parameters
      "kuwait" -> CalculationMethod.KUWAIT.parameters
      "turkey" -> CalculationMethod.TURKEY.parameters
      // adhan2 has no Tehran method; approximate it with custom angles.
      "tehran" -> CalculationMethod.OTHER.parameters.copy(fajrAngle = 17.7, ishaAngle = 14.0)
      "singapore" -> CalculationMethod.SINGAPORE.parameters
      "umm_al_qura" -> CalculationMethod.UMM_AL_QURA.parameters
      "north_america" -> CalculationMethod.NORTH_AMERICA.parameters
      "moon_sighting_committee" -> CalculationMethod.MOON_SIGHTING_COMMITTEE.parameters
      else -> CalculationMethod.OTHER.parameters
    }

    params = if (asrCalculation == "shafi") {
      params.copy(madhab = Madhab.SHAFI)
    } else {
      params.copy(madhab = Madhab.HANAFI)
    }

    if (kotlin.math.abs(lat) > 48.0) {
      val rule = when (highLatitudeRule) {
        "middle_of_night" -> HighLatitudeRule.MIDDLE_OF_THE_NIGHT
        "seventh_of_night" -> HighLatitudeRule.SEVENTH_OF_THE_NIGHT
        "twilight_angle" -> HighLatitudeRule.TWILIGHT_ANGLE
        else -> HighLatitudeRule.MIDDLE_OF_THE_NIGHT
      }
      params = params.copy(highLatitudeRule = rule)
    }

    return params
  }
}
