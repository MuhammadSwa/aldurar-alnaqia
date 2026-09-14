package com.example.aldurar_alnaqia

import android.app.AlarmManager
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
import android.os.PowerManager
import android.os.SystemClock
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
import java.time.Instant as JavaInstant
import java.time.ZoneId
import java.time.temporal.ChronoField
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.datetime.Instant
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlinx.datetime.plus
import kotlinx.datetime.toLocalDateTime
import org.json.JSONObject

/**
 * Native foreground service showing a persistent prayer-times notification
 * with a system-rendered countdown and exact AlarmManager-driven updates.
 *
 * Architecture inspired by Noorulhuda:
 *  - Uses [AlarmManager.setExactAndAllowWhileIdle] with [AlarmManager.RTC_WAKEUP]
 *    to wake the CPU precisely at prayer boundaries and midnight, avoiding
 *    Doze-mode stalls inherent in coroutine delay loops.
 *  - Holds a short partial [PowerManager.WakeLock] during calculations to ensure
 *    updates complete before the device returns to sleep.
 *  - Posts to two distinct channels:
 *     1. [CHANNEL_WIDGET_ID]: Ongoing, silent status-bar widget (low importance).
 *     2. [CHANNEL_ARRIVAL_ID]: Sound/alert notification when prayer time enters.
 */
class PrayerNotificationService : Service() {

  companion object {
    const val CHANNEL_WIDGET_ID = "prayer_timing_channel"
    const val CHANNEL_ARRIVAL_ID = "prayer_arrival_channel"

    const val WIDGET_NOTIFICATION_ID = 988
    const val ARRIVAL_NOTIFICATION_ID = 989

    private const val ALARM_REQUEST_CODE = 990
    private const val ACTION_ALARM_TRIGGER = "com.example.aldurar_alnaqia.PRAYER_ALARM_TRIGGER"

    private const val PREFS_FILE = "FlutterSharedPreferences"
    private const val KEY_CONFIG = "flutter.prayer_native_config"

    private const val NO_LOCATION_RETRY_MS = 15 * 60 * 1000L
    private const val NEXT_PRAYER_COLOR = 0xFF2E7D32.toInt()

    @Volatile
    private var running: PrayerNotificationService? = null

    @Volatile
    private var notificationPosted: Boolean = false

    fun refreshIfRunning() {
      running?.requestRefresh()
    }

    fun isRunning(): Boolean = running != null

    fun isNotificationPosted(): Boolean = notificationPosted

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
  }

  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
  private var wakeLock: PowerManager.WakeLock? = null

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    ensureChannels()
    running = this
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    startForeground(WIDGET_NOTIFICATION_ID, buildLoadingNotification())
    notificationPosted = true

    val isAlarmTrigger = intent?.action == ACTION_ALARM_TRIGGER
    requestRefresh(isAlarmTrigger = isAlarmTrigger)
    return START_STICKY
  }

  override fun onDestroy() {
    cancelExactAlarm()
    scope.cancel()
    if (running === this) running = null
    notificationPosted = false
    releaseWakeLock()

    getSystemService(NotificationManager::class.java)?.cancel(WIDGET_NOTIFICATION_ID)
    super.onDestroy()
  }

  fun requestRefresh(isAlarmTrigger: Boolean = false) {
    acquireWakeLock()
    scope.launch {
      try {
        runUpdate(isAlarmTrigger)
      } finally {
        releaseWakeLock()
      }
    }
  }

  // -------------------------------------------------------------------------
  // Wakelock Management
  // -------------------------------------------------------------------------

  private fun acquireWakeLock() {
    synchronized(this) {
      if (wakeLock == null) {
        val pm = getSystemService(PowerManager::class.java)
        wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "aldurar:PrayerNotifyWakeLock")
      }
      try {
        wakeLock?.acquire(10_000L) // 10-second safety limit
      } catch (_: Exception) {}
    }
  }

  private fun releaseWakeLock() {
    synchronized(this) {
      try {
        if (wakeLock?.isHeld == true) {
          wakeLock?.release()
        }
      } catch (_: Exception) {}
    }
  }

  // -------------------------------------------------------------------------
  // Exact AlarmManager Scheduling (Noorulhuda pattern)
  // -------------------------------------------------------------------------

  private fun canScheduleExactAlarms(): Boolean {
    val am = getSystemService(AlarmManager::class.java) ?: return false
    return Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
  }

  private fun scheduleNextWakeup(triggerAtMs: Long) {
    val am = getSystemService(AlarmManager::class.java) ?: return
    val intent = Intent(this, PrayerNotificationService::class.java).apply {
      action = ACTION_ALARM_TRIGGER
    }
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    val pi = PendingIntent.getService(this, ALARM_REQUEST_CODE, intent, flags)

    try {
      if (canScheduleExactAlarms()) {
        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
      } else {
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
      }
    } catch (_: SecurityException) {
      // Fallback if exact alarm permission was revoked
      am.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
    }
  }

  private fun cancelExactAlarm() {
    val am = getSystemService(AlarmManager::class.java) ?: return
    val intent = Intent(this, PrayerNotificationService::class.java).apply {
      action = ACTION_ALARM_TRIGGER
    }
    val flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
    val pi = PendingIntent.getService(this, ALARM_REQUEST_CODE, intent, flags)
    if (pi != null) {
      am.cancel(pi)
      pi.cancel()
    }
  }

  // -------------------------------------------------------------------------
  // Computation & Notification Update
  // -------------------------------------------------------------------------

  private suspend fun runUpdate(isAlarmTrigger: Boolean) {
    val cfg = readConfig(this)

    if (cfg == null || cfg.lat == 0.0 || cfg.lng == 0.0) {
      postFallback("الرجاء ضبط الموقع لحساب المواقيت")
      scheduleNextWakeup(System.currentTimeMillis() + NO_LOCATION_RETRY_MS)
      return
    }

    val nowMs = System.currentTimeMillis()
    val zone = cfg.zone()
    val plan = computePlan(cfg, zone, nowMs)

    if (plan == null) {
      postFallback("تعذّر حساب المواقيت")
      scheduleNextWakeup(System.currentTimeMillis() + NO_LOCATION_RETRY_MS)
      return
    }

    // If woken by an exact alarm boundary, check if a prayer time just started
    if (isAlarmTrigger) {
      maybePostPrayerArrivalAlert(plan, nowMs)
    }

    val hijri = hijriDateString(cfg, zone, nowMs, plan.maghribMs)

    postNotification(plan, hijri)

    // Target next event: either the upcoming prayer or midnight
    val nextWakeMs = computeNextWakeTimestamp(nowMs, zone, plan.nextAtMs)
    scheduleNextWakeup(nextWakeMs)
  }

  /**
   * Fires a sound alert notification when prayer enters (if within 2 minutes of boundary).
   */
  private fun maybePostPrayerArrivalAlert(plan: DayPlan, nowMs: Long) {
    for ((name, timeMs) in plan.times) {
      if (name == "الشروق") continue // Sunrise is not a prayer
      val diff = nowMs - timeMs
      if (diff in -15_000..90_000) {
        val nm = getSystemService(NotificationManager::class.java)
        val alert = NotificationCompat.Builder(this, CHANNEL_ARRIVAL_ID)
            .setSmallIcon(R.drawable.ic_stat_prayer)
            .setColor(NEXT_PRAYER_COLOR)
            .setContentTitle("حان الآن موعد صلاة $name")
            .setContentText("حيّ على الصلاة • حيّ على الفلاح")
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setContentIntent(contentIntent())
            .build()
        nm?.notify(ARRIVAL_NOTIFICATION_ID, alert)
        break
      }
    }
  }

  private fun computeNextWakeTimestamp(nowMs: Long, zone: TimeZone, nextPrayerAtMs: Long): Long {
    val nowDate = Instant.fromEpochMilliseconds(nowMs).toLocalDateTime(zone).date
    val nextMidnightMs = (nowDate.plus(1, kotlinx.datetime.DateTimeUnit.DAY))
        .atStartOfDayIn(zone)
        .toEpochMilliseconds()

    // Wake 1 second after whichever event happens first
    return if (nextPrayerAtMs in (nowMs + 1000)..nextMidnightMs) {
      nextPrayerAtMs + 1000
    } else {
      nextMidnightMs + 1000
    }
  }

  // -------------------------------------------------------------------------
  // Notification Builders
  // -------------------------------------------------------------------------

  private fun postFallback(message: String) {
    if (running !== this) return
    val nm = getSystemService(NotificationManager::class.java)
    nm?.notify(WIDGET_NOTIFICATION_ID, buildFallbackNotification(message))
    notificationPosted = true
  }

  private fun postNotification(plan: DayPlan, hijri: String) {
    if (running !== this) return
    val nm = getSystemService(NotificationManager::class.java)
    nm?.notify(WIDGET_NOTIFICATION_ID, buildNotification(plan, hijri))
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
      NotificationCompat.Builder(this, CHANNEL_WIDGET_ID)
          .setSmallIcon(R.drawable.ic_stat_prayer)
          .setColor(NEXT_PRAYER_COLOR)
          .setOngoing(true)
          .setOnlyAlertOnce(true)
          .setAutoCancel(false)
          .setSilent(true)
          .setShowWhen(false)
          .setContentIntent(contentIntent())

  private fun buildLoadingNotification(): Notification {
    val collapsed = RemoteViews(packageName, R.layout.notification_prayer_collapsed)
    val expanded = RemoteViews(packageName, R.layout.notification_prayer_expanded)
    collapsed.setTextViewText(R.id.next_label, "جارٍ حساب المواقيت...")
    collapsed.setViewVisibility(R.id.chronometer, android.view.View.GONE)
    expanded.setViewVisibility(R.id.chronometer, android.view.View.GONE)
    expanded.setTextViewText(R.id.hijri_date, "")
    for ((_, timeId) in PRAYER_SLOTS) {
      expanded.setTextViewText(timeId, "--:--")
    }
    return baseBuilder()
        .setCustomContentView(collapsed)
        .setCustomBigContentView(expanded)
        .build()
  }

  private fun buildFallbackNotification(message: String): Notification {
    val collapsed = RemoteViews(packageName, R.layout.notification_prayer_collapsed)
    val expanded = RemoteViews(packageName, R.layout.notification_prayer_expanded)
    collapsed.setTextViewText(R.id.next_label, message)
    collapsed.setViewVisibility(R.id.chronometer, android.view.View.GONE)
    expanded.setViewVisibility(R.id.chronometer, android.view.View.GONE)
    expanded.setTextViewText(R.id.hijri_date, "")
    for ((_, timeId) in PRAYER_SLOTS) {
      expanded.setTextViewText(timeId, "--:--")
    }
    return baseBuilder()
        .setCustomContentView(collapsed)
        .setCustomBigContentView(expanded)
        .build()
  }

  private fun buildNotification(plan: DayPlan, hijri: String): Notification {
    val collapsed = RemoteViews(packageName, R.layout.notification_prayer_collapsed)
    val expanded = RemoteViews(packageName, R.layout.notification_prayer_expanded)

    val nextLabel = "الصلاة القادمة: ${plan.nextName}"
    collapsed.setTextViewText(R.id.next_label, nextLabel)
    expanded.setTextViewText(R.id.hijri_date, hijri)

    // System-managed chronometer: SystemUI updates every second with 0 app wakeups
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      val remaining = (plan.nextAtMs - System.currentTimeMillis()).coerceAtLeast(0)
      val base = SystemClock.elapsedRealtime() + remaining
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

    val zone = currentZone()
    val defaultTextColor = 0xFFDDDDDD.toInt()

    // When the device is in an RTL locale (Arabic), LinearLayout puts slot 1 (child 0)
    // on the physical RIGHT. When in an LTR locale (English), slot 6 (child 5) is on the physical RIGHT.
    // We dynamically order prayers so that Maghrib is ALWAYS on the physical right and Asr on the physical left
    // (Islamic day starts at Maghrib).
    val isSystemRtl = android.text.TextUtils.getLayoutDirectionFromLocale(
        Locale.getDefault()) == android.view.View.LAYOUT_DIRECTION_RTL

    // Reorder from Fajr-first [Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha]
    // to Maghrib-first [Maghrib, Isha, Fajr, Sunrise, Dhuhr, Asr].
    val maghribFirst = listOf("المغرب", "العشاء", "الفجر", "الشروق", "الظهر", "العصر")
        .mapNotNull { wanted -> plan.times.firstOrNull { it.first == wanted } }
        .takeIf { it.size == plan.times.size } ?: plan.times

    val orderedPrayers = if (isSystemRtl) {
      maghribFirst // Slot 1 (Right) -> Slot 6 (Left): [Maghrib, Isha, Fajr, Sunrise, Dhuhr, Asr]
    } else {
      maghribFirst.reversed() // Slot 1 (Left) -> Slot 6 (Right): [Asr, Dhuhr, Sunrise, Fajr, Isha, Maghrib]
    }

    PRAYER_SLOTS.forEachIndexed { i, (nameId, timeId) ->
      val (name, ms) = orderedPrayers[i]
      expanded.setTextViewText(nameId, name)
      expanded.setTextViewText(timeId, formatTime(ms, zone))

      if (name == plan.nextName) {
        expanded.setTextColor(nameId, NEXT_PRAYER_COLOR)
        expanded.setTextColor(timeId, NEXT_PRAYER_COLOR)
      } else {
        expanded.setTextColor(nameId, defaultTextColor)
        expanded.setTextColor(timeId, defaultTextColor)
      }
    }

    return baseBuilder()
        .setCustomContentView(collapsed)
        .setCustomBigContentView(expanded)
        .build()
  }

  private fun currentZone(): TimeZone =
      try {
        readConfig(this)?.zone() ?: TimeZone.currentSystemDefault()
      } catch (_: Exception) {
        TimeZone.currentSystemDefault()
      }

  private val PRAYER_SLOTS = listOf(
      R.id.prayer1_name to R.id.prayer1_time,
      R.id.prayer2_name to R.id.prayer2_time,
      R.id.prayer3_name to R.id.prayer3_time,
      R.id.prayer4_name to R.id.prayer4_time,
      R.id.prayer5_name to R.id.prayer5_time,
      R.id.prayer6_name to R.id.prayer6_time)

  private fun ensureChannels() {
    val nm = getSystemService(NotificationManager::class.java) ?: return

    // 1. Persistent widget channel (silent, low importance)
    val widgetChannel = NotificationChannel(
        CHANNEL_WIDGET_ID,
        "مواقيت الصلاة (شريط الحالة)",
        NotificationManager.IMPORTANCE_LOW
    ).apply {
      description = "إشعار دائم يعرض مواقيت الصلاة والعد التنازلي للصلاة التالية"
      enableVibration(false)
      enableLights(false)
      setShowBadge(false)
      setSound(null, null)
    }
    nm.createNotificationChannel(widgetChannel)

    // 2. Prayer arrival channel (sound, default importance)
    val arrivalChannel = NotificationChannel(
        CHANNEL_ARRIVAL_ID,
        "تنبيهات دخول وقت الصلاة",
        NotificationManager.IMPORTANCE_DEFAULT
    ).apply {
      description = "تنبيه عند حلول موعد الأذان والصلاة"
      enableVibration(true)
      enableLights(true)
      setShowBadge(true)
    }
    nm.createNotificationChannel(arrivalChannel)
  }

  // -------------------------------------------------------------------------
  // Config & Calculations
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

    val todayTimes = prayerTimesList(coordinates, params, now.date, zone) ?: return null
    val maghribMs = todayTimes.firstOrNull { it.first == "المغرب" }?.second
    val next = todayTimes.firstOrNull { it.second > nowMs }

    if (next != null) {
      return DayPlan(todayTimes, next.first, next.second, maghribMs)
    }

    // After Isha: tomorrow's Fajr is the upcoming prayer
    val tomorrow = now.date.plus(1, kotlinx.datetime.DateTimeUnit.DAY)
    val tomorrowFajr = prayerTimesList(coordinates, params, tomorrow, zone)
        ?.firstOrNull()?.second ?: return null
    return DayPlan(todayTimes, "الفجر", tomorrowFajr, maghribMs)
  }

  private fun formatTime(ms: Long, zone: TimeZone): String {
    val fmt = SimpleDateFormat("hh:mm", Locale.US).apply {
      timeZone = java.util.TimeZone.getTimeZone(zone.id)
    }
    val period = if (hourOf(ms, zone) < 12) "ص" else "م"
    return "${fmt.format(Date(ms))} $period"
  }

  private fun hijriDateString(
    cfg: Config,
    zone: TimeZone,
    nowMs: Long,
    maghribMs: Long?
  ): String {
    return try {
      val zoneId = try { ZoneId.of(zone.id) } catch (_: Exception) { ZoneId.systemDefault() }
      var gregorian = JavaInstant.ofEpochMilli(nowMs).atZone(zoneId).toLocalDate()
      gregorian = gregorian.plusDays(cfg.hijriOffset.toLong())
      if (maghribMs != null && nowMs >= maghribMs) {
        gregorian = gregorian.plusDays(1)
      }
      val hijrah = java.time.chrono.HijrahDate.from(gregorian)
      val day = hijrah.get(ChronoField.DAY_OF_MONTH)
      val month = hijrah.get(ChronoField.MONTH_OF_YEAR)
      val year = hijrah.get(ChronoField.YEAR)
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
