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
import android.widget.RemoteViews
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
    startForeground(NOTIFICATION_ID, buildLoadingNotification())
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
      postFallback("الرجاء ضبط الموقع لحساب المواقيت")
      scheduleNext(NO_LOCATION_RETRY_MS)
      return
    }

    val nowMs = System.currentTimeMillis()
    val zone = cfg.zone()
    val plan = computePlan(cfg, zone, nowMs)

    if (plan == null) {
      postFallback("تعذّر حساب المواقيت")
      scheduleNext(NO_LOCATION_RETRY_MS)
      return
    }

    val hijri = hijriDateString(cfg, zone, nowMs, plan.maghribMs)
    postNotification(plan, hijri)

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

  private fun postFallback(message: String) {
    // Never post after the service has been asked to stop.
    if (running !== this) return
    val nm = getSystemService(NotificationManager::class.java)
    nm?.notify(NOTIFICATION_ID, buildFallbackNotification(message))
    notificationPosted = true
  }

  private fun postNotification(plan: DayPlan, hijri: String) {
    // Never post after the service has been asked to stop.
    if (running !== this) return
    val nm = getSystemService(NotificationManager::class.java)
    nm?.notify(NOTIFICATION_ID, buildNotification(plan, hijri))
    notificationPosted = true
  }

  private fun contentIntent(): PendingIntent {
    val openIntent = Intent(this, MainActivity::class.java).apply {
      action = "$packageName.OPEN_TIMINGS"
      putExtra(MainActivity.EXTRA_ROUTE, "/timings")
      addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }
    return PendingIntent.getActivity(
        this, 0, openIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
  }

  private fun baseBuilder(): NotificationCompat.Builder =
      NotificationCompat.Builder(this, CHANNEL_ID)
          .setSmallIcon(R.drawable.ic_stat_prayer)
          .setColor(0xFF2E7D32.toInt())
          .setOngoing(true)
          .setOnlyAlertOnce(true)
          .setAutoCancel(false)
          .setSilent(true)
          .setShowWhen(false)
          .setContentIntent(contentIntent())

  /** Placeholder shown briefly while the first computation runs. */
  private fun buildLoadingNotification(): Notification {
    val collapsed = RemoteViews(packageName, R.layout.notification_prayer_collapsed)
    val expanded = RemoteViews(packageName, R.layout.notification_prayer_expanded)
    enforceLayout(collapsed, expanded)
    collapsed.setTextViewText(R.id.next_label, "جارٍ التحديث...")
    collapsed.setViewVisibility(R.id.chronometer, android.view.View.GONE)
    expanded.setViewVisibility(R.id.chronometer, android.view.View.GONE)
    expanded.setTextViewText(R.id.hijri_date, "")
    fillTableNames(expanded, displayNames())
    for (id in prayerTimeViewIds()) expanded.setTextViewText(id, "--:--")
    return baseBuilder()
        .setCustomContentView(collapsed)
        .setCustomBigContentView(expanded)
        .build()
  }

  /** Error / no-location state: message only, no countdown, no times. */
  private fun buildFallbackNotification(message: String): Notification {
    val collapsed = RemoteViews(packageName, R.layout.notification_prayer_collapsed)
    val expanded = RemoteViews(packageName, R.layout.notification_prayer_expanded)
    enforceLayout(collapsed, expanded)
    collapsed.setTextViewText(R.id.next_label, message)
    collapsed.setViewVisibility(R.id.chronometer, android.view.View.GONE)
    expanded.setViewVisibility(R.id.chronometer, android.view.View.GONE)
    expanded.setTextViewText(R.id.hijri_date, "")
    fillTableNames(expanded, displayNames())
    for (id in prayerTimeViewIds()) expanded.setTextViewText(id, "--:--")
    return baseBuilder()
        .setCustomContentView(collapsed)
        .setCustomBigContentView(expanded)
        .build()
  }

  private fun buildNotification(plan: DayPlan, hijri: String): Notification {
    val collapsed = RemoteViews(packageName, R.layout.notification_prayer_collapsed)
    val expanded = RemoteViews(packageName, R.layout.notification_prayer_expanded)
    enforceLayout(collapsed, expanded)

    val nextLabel = "الصلاة القادمة: ${plan.nextName}"
    collapsed.setTextViewText(R.id.next_label, nextLabel)
    expanded.setTextViewText(R.id.hijri_date, hijri)

    // Native count-down chronometer rendered by the system — no app wakeups.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      val remaining = (plan.nextAtMs - System.currentTimeMillis()).coerceAtLeast(0)
      val base = android.os.SystemClock.elapsedRealtime() + remaining
      collapsed.setViewVisibility(R.id.chronometer, android.view.View.VISIBLE)
      expanded.setViewVisibility(R.id.chronometer, android.view.View.VISIBLE)
      collapsed.setChronometer(R.id.chronometer, base, null, true)
      expanded.setChronometer(R.id.chronometer, base, null, true)
      collapsed.setChronometerCountDown(R.id.chronometer, true)
      expanded.setChronometerCountDown(R.id.chronometer, true)
    } else {
      collapsed.setViewVisibility(R.id.chronometer, android.view.View.GONE)
      expanded.setViewVisibility(R.id.chronometer, android.view.View.GONE)
    }

    // Horizontal table: slots are filled by position (names too, not just
    // times) so the visual order stays correct even on hosts that mirror
    // the layout direction to the system locale.
    val zone = currentZone()
    val rows = if (needsReversedSlots()) plan.times.reversed() else plan.times
    tableSlots().forEachIndexed { i, slot ->
      val (name, ms) = rows[i]
      expanded.setTextViewText(slot.nameId, name)
      expanded.setTextViewText(slot.timeId, formatTime(ms, zone))
      if (name == plan.nextName) {
        // Highlight the upcoming prayer; others keep the system default
        // color so they adapt to light/dark notification backgrounds.
        expanded.setTextColor(slot.nameId, NEXT_PRAYER_COLOR)
        expanded.setTextColor(slot.timeId, NEXT_PRAYER_COLOR)
      }
    }

    return baseBuilder()
        .setCustomContentView(collapsed)
        .setCustomBigContentView(expanded)
        .build()
  }

  /**
   * Forces RTL ordering + text sizes at runtime. Some hosts (MIUI/HyperOS,
   * Android 12+ decorated templates) reset custom-view layout direction and
   * text sizes to the system locale at inflation time; RemoteViews actions
   * run after inflation so these stick. Harmless no-op elsewhere.
   */
  private fun enforceLayout(collapsed: RemoteViews, expanded: RemoteViews) {
    for (id in listOf(R.id.collapsed_root)) {
      collapsed.setInt(id, "setLayoutDirection", android.view.View.LAYOUT_DIRECTION_RTL)
    }
    for (id in listOf(R.id.expanded_root, R.id.top_row, R.id.table_row)) {
      expanded.setInt(id, "setLayoutDirection", android.view.View.LAYOUT_DIRECTION_RTL)
    }
    val names = listOf(R.id.name_fajr, R.id.name_sunrise, R.id.name_dhuhr,
        R.id.name_asr, R.id.name_maghrib, R.id.name_isha)
    val times = listOf(R.id.time_fajr, R.id.time_sunrise, R.id.time_dhuhr,
        R.id.time_asr, R.id.time_maghrib, R.id.time_isha)
    val seps = listOf(R.id.sep1, R.id.sep2, R.id.sep3, R.id.sep4, R.id.sep5)
    for (id in names) {
      expanded.setTextViewTextSize(
          id, android.util.TypedValue.COMPLEX_UNIT_SP, 12f)
    }
    for (id in times) {
      expanded.setTextViewTextSize(
          id, android.util.TypedValue.COMPLEX_UNIT_SP, 11f)
    }
    for (id in seps) {
      expanded.setTextViewTextSize(
          id, android.util.TypedValue.COMPLEX_UNIT_SP, 10f)
    }
    // Heading: smaller, non-bold (regular Notification style in XML).
    // NOTE: the expanded view has no next_label (collapsed only).
    for (id in listOf(R.id.chronometer, R.id.hijri_date)) {
      expanded.setTextViewTextSize(
          id, android.util.TypedValue.COMPLEX_UNIT_SP, 14f)
    }
    for (id in listOf(R.id.next_label, R.id.chronometer)) {
      collapsed.setTextViewTextSize(
          id, android.util.TypedValue.COMPLEX_UNIT_SP, 14f)
    }
  }

  private fun currentZone(): TimeZone =
      try {
        readConfig(this)?.zone() ?: TimeZone.currentSystemDefault()
      } catch (_: Exception) {
        TimeZone.currentSystemDefault()
      }

  private fun prayerTimeViewIds(): List<Int> = listOf(
      R.id.time_fajr, R.id.time_sunrise, R.id.time_dhuhr,
      R.id.time_asr, R.id.time_maghrib, R.id.time_isha)

  private data class TableSlot(val nameId: Int, val timeId: Int)

  /** Table columns in XML source order (Fajr first). */
  private fun tableSlots(): List<TableSlot> = listOf(
      TableSlot(R.id.name_fajr, R.id.time_fajr),
      TableSlot(R.id.name_sunrise, R.id.time_sunrise),
      TableSlot(R.id.name_dhuhr, R.id.time_dhuhr),
      TableSlot(R.id.name_asr, R.id.time_asr),
      TableSlot(R.id.name_maghrib, R.id.time_maghrib),
      TableSlot(R.id.name_isha, R.id.time_isha))

  private val PRAYER_NAMES =
      listOf("الفجر", "الشروق", "الظهر", "العصر", "المغرب", "العشاء")

  private val NEXT_PRAYER_COLOR = 0xFF43A047.toInt()

  /** Prayer names in visual slot order (mirrored when slots are reversed). */
  private fun displayNames(): List<String> =
      if (needsReversedSlots()) PRAYER_NAMES.reversed() else PRAYER_NAMES

  private fun fillTableNames(expanded: RemoteViews, names: List<String>) {
    tableSlots().forEachIndexed { i, slot ->
      expanded.setTextViewText(slot.nameId, names[i])
    }
  }

  /**
   * True when the host renders slot 0 leftmost: MIUI/HyperOS forces custom
   * notification direction to the system locale *after* RemoteViews actions
   * are applied. Only matters on LTR-locale devices (on RTL locales the
   * forced direction is RTL anyway). Everywhere else our explicit RTL is
   * honored and slots fill in source order.
   */
  private fun needsReversedSlots(): Boolean {
    val systemRtl = android.text.TextUtils.getLayoutDirectionFromLocale(
        Locale.getDefault()) == android.view.View.LAYOUT_DIRECTION_RTL
    if (systemRtl) return false
    val manufacturer = android.os.Build.MANUFACTURER.lowercase(Locale.US)
    val brand = android.os.Build.BRAND.lowercase(Locale.US)
    return manufacturer.contains("xiaomi") || brand.contains("xiaomi") ||
        brand.contains("redmi") || brand.contains("poco")
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
    val timezone: String,
    val hijriOffset: Int
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
          timezone = o.optString("timezone", ""),
          hijriOffset = o.optInt("hijriOffset", 0))
    } catch (_: Exception) {
      null
    }
  }

  private class DayPlan(
    val times: List<Pair<String, Long>>,
    val nextName: String,
    val nextAtMs: Long,
    val maghribMs: Long?
  )

  private fun computePlan(cfg: Config, zone: TimeZone, nowMs: Long): DayPlan? {
    val params = buildParams(cfg.method, cfg.asrCalculation, cfg.highLatitudeRule, cfg.lat)
    val coordinates = Coordinates(cfg.lat, cfg.lng)
    val now = Instant.fromEpochMilliseconds(nowMs).toLocalDateTime(zone)

    val todayTimes = prayerTimesList(coordinates, params, now.date, zone)
        ?: return null
    val maghribMs = todayTimes.firstOrNull { it.first == "المغرب" }?.second
    val next = todayTimes.firstOrNull { it.second > nowMs }

    if (next != null) {
      return DayPlan(todayTimes, next.first, next.second, maghribMs)
    }

    // After Isha: show tomorrow's Fajr as the upcoming prayer.
    val tomorrow = now.date.plus(1, kotlinx.datetime.DateTimeUnit.DAY)
    val tomorrowFajr = prayerTimesList(coordinates, params, tomorrow, zone)
        ?.firstOrNull()?.second ?: return null
    return DayPlan(todayTimes, "الفجر", tomorrowFajr, maghribMs)
  }

  /** "05:11 ص" style time, matching the in-app prayer card. */
  private fun formatTime(ms: Long, zone: TimeZone): String {
    val fmt = SimpleDateFormat("hh:mm", Locale.US).apply {
      timeZone = java.util.TimeZone.getTimeZone(zone.id)
    }
    val period = if (hourOf(ms, zone) < 12) "ص" else "م"
    return "${fmt.format(Date(ms))} $period"
  }

  /**
   * Hijri date like "3 ربيع الآخر 1448", honoring the user day offset.
   * The Islamic day rolls over at Maghrib, mirroring the in-app widget.
   * Month names are mapped manually: localized MMMM text is unreliable
   * in notifications on some firmwares (renders as a bare month number).
   */
  private fun hijriDateString(
    cfg: Config,
    zone: TimeZone,
    nowMs: Long,
    maghribMs: Long?
  ): String {
    return try {
      val zoneId = try {
        java.time.ZoneId.of(zone.id)
      } catch (_: Exception) {
        java.time.ZoneId.systemDefault()
      }
      var gregorian =
          java.time.Instant.ofEpochMilli(nowMs).atZone(zoneId).toLocalDate()
      gregorian = gregorian.plusDays(cfg.hijriOffset.toLong())
      if (maghribMs != null && nowMs >= maghribMs) {
        gregorian = gregorian.plusDays(1)
      }
      val hijrah = java.time.chrono.HijrahDate.from(gregorian)
      val day = hijrah.get(java.time.temporal.ChronoField.DAY_OF_MONTH)
      val month = hijrah.get(java.time.temporal.ChronoField.MONTH_OF_YEAR)
      val year = hijrah.get(java.time.temporal.ChronoField.YEAR)
      "$day ${hijriMonthName(month)} $year"
    } catch (_: Exception) {
      ""
    }
  }

  private fun hijriMonthName(month: Int): String = when (month) {
    1 -> "محرم"
    2 -> "صفر"
    3 -> "ربيع الأول"
    4 -> "ربيع الآخر"
    5 -> "جمادى الأولى"
    6 -> "جمادى الآخرة"
    7 -> "رجب"
    8 -> "شعبان"
    9 -> "رمضان"
    10 -> "شوال"
    11 -> "ذو القعدة"
    else -> "ذو الحجة"
  }

  private fun hourOf(ms: Long, zone: TimeZone): Int =
      Instant.fromEpochMilliseconds(ms).toLocalDateTime(zone).hour

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
