package com.dorar.yosriya

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
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import org.json.JSONArray
import org.json.JSONObject

/**
 * Native foreground service showing a persistent prayer-times notification
 * with a system-rendered countdown and exact AlarmManager-driven updates.
 *
 * Dart owns ALL prayer math (adhan_dart): it writes precomputed epoch-ms
 * timetables (`days` + `midnights`, contract v2) into the config JSON.
 * This service only renders + schedules alarms — no solar calculation here,
 * so there is a single source of truth and no method/madhab divergence.
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
    private const val ACTION_ALARM_TRIGGER = "com.dorar.yosriya.PRAYER_ALARM_TRIGGER"

    private const val PREFS_FILE = "FlutterSharedPreferences"
    private const val KEY_CONFIG = "flutter.prayer_native_config"

    private const val NO_LOCATION_RETRY_MS = 15 * 60 * 1000L
    private const val NEXT_PRAYER_COLOR = 0xFF2E7D32.toInt()

    @Volatile
    private var running: PrayerNotificationService? = null

    fun refreshIfRunning() {
      running?.requestRefresh()
    }

    fun isRunning(): Boolean = running != null

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
  }

  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
  private var wakeLock: PowerManager.WakeLock? = null

  // Serializes notification updates: settings saves, alarm deliveries and
  // service starts can otherwise race (notify + scheduleNextWakeup are
  // last-writer-wins, so a stale cycle could leave a stale alarm behind).
  private val refreshMutex = Mutex()

  // Guarded by `synchronized(this)`. Set when a refresh arrives mid-update;
  // the running cycle re-runs once more instead of overlapping.
  private var pendingRefresh = false

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    ensureChannels()
    running = this
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    startForeground(WIDGET_NOTIFICATION_ID, buildLoadingNotification())

    val isAlarmTrigger = intent?.action == ACTION_ALARM_TRIGGER
    requestRefresh(isAlarmTrigger = isAlarmTrigger)
    return START_STICKY
  }

  override fun onDestroy() {
    cancelExactAlarm()
    scope.cancel()
    if (running === this) running = null
    releaseWakeLock()

    getSystemService(NotificationManager::class.java)?.cancel(WIDGET_NOTIFICATION_ID)
    super.onDestroy()
  }

  fun requestRefresh(isAlarmTrigger: Boolean = false) {
    scope.launch {
      // Coalesce bursts instead of overlapping: if an update is already
      // running, mark one follow-up and return.
      if (!refreshMutex.tryLock()) {
        synchronized(this@PrayerNotificationService) { pendingRefresh = true }
        return@launch
      }
      try {
        acquireWakeLock()
        try {
          runUpdate(isAlarmTrigger)
        } finally {
          releaseWakeLock()
        }
        // Drain at most one coalesced follow-up per burst.
        while (true) {
          val again = synchronized(this@PrayerNotificationService) {
            val p = pendingRefresh
            pendingRefresh = false
            p
          }
          if (!again) break
          acquireWakeLock()
          try {
            runUpdate(false)
          } finally {
            releaseWakeLock()
          }
        }
      } finally {
        refreshMutex.unlock()
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

  private fun scheduleNextWakeup(triggerAtMs: Long, exact: Boolean) {
    val am = getSystemService(AlarmManager::class.java) ?: return
    val intent = Intent(this, PrayerNotificationService::class.java).apply {
      action = ACTION_ALARM_TRIGGER
    }
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    val pi = PendingIntent.getService(this, ALARM_REQUEST_CODE, intent, flags)

    // Always-exact policy: alertable prayer boundaries wake the device out
    // of Doze. Midnight/sunrise/fallback refreshes use inexact alarms — the
    // displayed countdown is a system Chronometer, so it keeps ticking
    // correctly without an exact wakeup.
    try {
      if (exact && canScheduleExactAlarms()) {
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

    if (cfg == null || (cfg.lat == 0.0 && cfg.lng == 0.0)) {
      postFallback("الرجاء ضبط الموقع لحساب المواقيت")
      scheduleNextWakeup(System.currentTimeMillis() + NO_LOCATION_RETRY_MS, exact = false)
      return
    }

    val nowMs = System.currentTimeMillis()
    // Dumb renderer: pick next/display from Dart-precomputed tables.
    // Empty `days` means a v1 config (pre-update install) or invalid
    // settings — one app open rewrites it to v2.
    val plan = findPlan(cfg, nowMs)

    if (plan == null) {
      postFallback("افتح التطبيق لتحديث المواقيت")
      scheduleNextWakeup(System.currentTimeMillis() + NO_LOCATION_RETRY_MS, exact = false)
      return
    }

    // If woken by an exact alarm boundary, check if a prayer time just started
    if (isAlarmTrigger) {
      maybePostPrayerArrivalAlert(plan, nowMs)
    }

    val hijri = hijriDateString(cfg, nowMs, plan.maghribMs)

    postNotification(plan, hijri)

    // Target next event: either the upcoming prayer or midnight.
    // Exact wakeup for alertable prayers; midnight/sunrise stay inexact.
    val (nextWakeMs, exact) = computeNextWake(cfg, nowMs, plan)
    scheduleNextWakeup(nextWakeMs, exact)
  }

  /**
   * Fires a sound alert notification when prayer enters (if within 2 minutes of boundary).
   * Sunrise is identified by ID (never by display string) and never alerts.
   */
  private fun maybePostPrayerArrivalAlert(plan: DayPlan, nowMs: Long) {
    for (event in plan.times) {
      if (!event.isPrayer) continue // Sunrise is not a prayer
      val diff = nowMs - event.atMs
      if (diff in -15_000..90_000) {
        val nm = getSystemService(NotificationManager::class.java)
        val alert = NotificationCompat.Builder(this, CHANNEL_ARRIVAL_ID)
            .setSmallIcon(R.drawable.ic_stat_prayer)
            .setColor(NEXT_PRAYER_COLOR)
            .setContentTitle("حان الآن موعد صلاة ${event.id.arabicName}")
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

  /**
   * Next wakeup as (timestamp, exact): exact when the upcoming boundary
   * is an alertable prayer. Midnight and sunrise use inexact alarms
   * (Chronometer display needs no exact wakeup). Midnight boundaries come
   * from Dart's precomputed `midnights` — no date math here.
   */
  private fun computeNextWake(
    cfg: Config,
    nowMs: Long,
    plan: DayPlan
  ): Pair<Long, Boolean> {
    val nextMidnightMs = cfg.midnights.firstOrNull { it > nowMs }

    if (nextMidnightMs == null) {
      return (plan.nextAtMs + 1000) to plan.nextIsPrayer
    }
    // Wake 1 second after whichever event happens first
    return if (plan.nextAtMs in (nowMs + 1000)..nextMidnightMs) {
      (plan.nextAtMs + 1000) to plan.nextIsPrayer
    } else {
      (nextMidnightMs + 1000) to false
    }
  }

  // -------------------------------------------------------------------------
  // Notification Builders
  // -------------------------------------------------------------------------

  private fun postFallback(message: String) {
    if (running !== this) return
    val nm = getSystemService(NotificationManager::class.java)
    nm?.notify(WIDGET_NOTIFICATION_ID, buildFallbackNotification(message))
  }

  private fun postNotification(plan: DayPlan, hijri: String) {
    if (running !== this) return
    val nm = getSystemService(NotificationManager::class.java)
    nm?.notify(WIDGET_NOTIFICATION_ID, buildNotification(plan, hijri))
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

    collapsed.setTextViewText(R.id.next_label, "${plan.nextId.arabicName} بعد")
    expanded.setTextViewText(R.id.hijri_date, hijri)

    // System-managed chronometer: SystemUI updates every second with 0 app wakeups.
    // Exact zero-crossing matches the in-app countdown. If the refresh lands
    // late, the remaining <= 0 branch below freezes at 00:00:00 instead of
    // showing a minus. (minSdk 24, so no pre-N fallback.)
    val remaining = plan.nextAtMs - System.currentTimeMillis()
    if (remaining <= 0) {
      collapsed.setViewVisibility(R.id.chronometer, android.view.View.VISIBLE)
      expanded.setViewVisibility(R.id.chronometer, android.view.View.VISIBLE)
      collapsed.setTextViewText(R.id.chronometer, "00:00:00")
      expanded.setTextViewText(R.id.chronometer, "00:00:00")
    } else {
      val base = SystemClock.elapsedRealtime() + remaining
      collapsed.setViewVisibility(R.id.chronometer, android.view.View.VISIBLE)
      expanded.setViewVisibility(R.id.chronometer, android.view.View.VISIBLE)
      collapsed.setChronometer(R.id.chronometer, base, null, true)
      expanded.setChronometer(R.id.chronometer, base, null, true)
      collapsed.setChronometerCountDown(R.id.chronometer, true)
      expanded.setChronometerCountDown(R.id.chronometer, true)
    }

    val zoneId = currentZoneId()

    // When the device is in an RTL locale (Arabic), LinearLayout puts slot 1 (child 0)
    // on the physical RIGHT. When in an LTR locale (English), slot 6 (child 5) is on the physical RIGHT.
    // We dynamically order prayers so that Maghrib is ALWAYS on the physical right and Asr on the physical left
    // (Islamic day starts at Maghrib).
    val isSystemRtl = android.text.TextUtils.getLayoutDirectionFromLocale(
        Locale.getDefault()) == android.view.View.LAYOUT_DIRECTION_RTL

    // Reorder from Fajr-first [Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha]
    // to Maghrib-first [Maghrib, Isha, Fajr, Sunrise, Dhuhr, Asr].
    val maghribFirst = listOf(
        EventId.MAGHRIB, EventId.ISHA, EventId.FAJR,
        EventId.SUNRISE, EventId.DHUHR, EventId.ASR)
        .mapNotNull { wanted -> plan.times.firstOrNull { it.id == wanted } }
        .takeIf { it.size == plan.times.size } ?: plan.times

    val orderedPrayers = if (isSystemRtl) {
      maghribFirst // Slot 1 (Right) -> Slot 6 (Left): [Maghrib, Isha, Fajr, Sunrise, Dhuhr, Asr]
    } else {
      maghribFirst.reversed() // Slot 1 (Left) -> Slot 6 (Right): [Asr, Dhuhr, Sunrise, Fajr, Isha, Maghrib]
    }

    PRAYER_SLOTS.forEachIndexed { i, (nameId, timeId) ->
      val event = orderedPrayers[i]
      expanded.setTextViewText(nameId, event.id.arabicName)
      expanded.setTextViewText(timeId, formatTime(event.atMs, zoneId))

      if (event.id == plan.nextId) {
        expanded.setTextColor(nameId, NEXT_PRAYER_COLOR)
        expanded.setTextColor(timeId, NEXT_PRAYER_COLOR)
      }
    }

    return baseBuilder()
        .setCustomContentView(collapsed)
        .setCustomBigContentView(expanded)
        .build()
  }

  private fun currentZoneId(): String =
      try {
        readConfig(this)?.timezone?.ifEmpty { "UTC" } ?: "UTC"
      } catch (_: Exception) {
        "UTC"
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
  // Config & precomputed timetables (cross-platform contract v2 — see Dart
  // `models/prayer_schedule.dart`. Dart owns ALL solar math and writes
  // `days` (N civil days × 6 epoch-ms) + `midnights` (N+1 boundaries).
  // Kotlin only selects next/display and schedules alarms. Event IDs are
  // stable enums here; Arabic labels exist ONLY in `EventId.arabicName`.)
  // -------------------------------------------------------------------------

  /** Stable event identifiers. SUNRISE.isPrayer == false: it advances the
   * next-event state but must never fire an arrival alert. */
  enum class EventId(val arabicName: String, val isPrayer: Boolean) {
    FAJR("الفجر", true),
    SUNRISE("الشروق", false),
    DHUHR("الظهر", true),
    ASR("العصر", true),
    MAGHRIB("المغرب", true),
    ISHA("العشاء", true)
  }

  data class PrayerEvent(val id: EventId, val atMs: Long) {
    val isPrayer: Boolean get() = id.isPrayer
  }

  data class Config(
    val lat: Double,
    val lng: Double,
    val timezone: String,
    val hijriOffset: Int,
    val days: List<List<PrayerEvent>>,
    val midnights: List<Long>
  )

  private fun readConfig(context: Context): Config? {
    val raw = prefs(context).getString(KEY_CONFIG, null) ?: return null
    return try {
      val o = JSONObject(raw)
      Config(
          lat = o.getDouble("lat"),
          lng = o.getDouble("lng"),
          timezone = o.optString("timezone", ""),
          hijriOffset = o.optInt("hijriOffset", 0),
          days = parseDays(o.optJSONArray("days")),
          midnights = parseLongs(o.optJSONArray("midnights")))
    } catch (_: Exception) {
      null
    }
  }

  private fun parseDays(arr: JSONArray?): List<List<PrayerEvent>> {
    if (arr == null) return emptyList()
    val out = ArrayList<List<PrayerEvent>>(arr.length())
    for (i in 0 until arr.length()) {
      val d = arr.optJSONObject(i) ?: continue
      val day = listOf(
          PrayerEvent(EventId.FAJR, d.optLong("fajr", 0L)),
          PrayerEvent(EventId.SUNRISE, d.optLong("sunrise", 0L)),
          PrayerEvent(EventId.DHUHR, d.optLong("dhuhr", 0L)),
          PrayerEvent(EventId.ASR, d.optLong("asr", 0L)),
          PrayerEvent(EventId.MAGHRIB, d.optLong("maghrib", 0L)),
          PrayerEvent(EventId.ISHA, d.optLong("isha", 0L)))
      if (day.any { it.atMs <= 0L }) continue
      out.add(day)
    }
    return out
  }

  private fun parseLongs(arr: JSONArray?): List<Long> {
    if (arr == null) return emptyList()
    val out = ArrayList<Long>(arr.length())
    for (i in 0 until arr.length()) {
      val v = arr.optLong(i, 0L)
      if (v > 0L) out.add(v)
    }
    return out
  }

  private class DayPlan(
    val times: List<PrayerEvent>,
    val nextId: EventId,
    val nextAtMs: Long,
    val maghribMs: Long?
  ) {
    val nextIsPrayer: Boolean get() = nextId.isPrayer
  }

  /**
   * Selects display + next from Dart-precomputed tables (no calculation).
   * Display = the civil day containing `nowMs` (via `midnights`); next =
   * first event strictly after `nowMs` across all days. After Isha this is
   * tomorrow's Fajr. Returns null when the window is empty (v1 config /
   * invalid settings) or expired (past the last midnight/event: one app
   * open rewrites a fresh 30-day window).
   */
  private fun findPlan(cfg: Config, nowMs: Long): DayPlan? {
    if (cfg.days.isEmpty() || cfg.midnights.isEmpty()) return null
    if (nowMs >= (cfg.midnights.lastOrNull() ?: Long.MAX_VALUE)) return null

    var todayIdx = 0
    for (i in cfg.midnights.indices) {
      if (cfg.midnights[i] <= nowMs) {
        todayIdx = i
      } else {
        break
      }
    }
    if (todayIdx >= cfg.days.size) return null
    val times = cfg.days[todayIdx]

    var next: PrayerEvent? = null
    outer@ for (day in cfg.days) {
      for (event in day) {
        if (event.atMs > nowMs) {
          next = event
          break@outer
        }
      }
    }
    val n = next ?: return null
    return DayPlan(times, n.id, n.atMs,
        times.firstOrNull { it.id == EventId.MAGHRIB }?.atMs)
  }

  private fun formatTime(ms: Long, zoneId: String): String {
    val fmt = SimpleDateFormat("hh:mm", Locale.US).apply {
      timeZone = java.util.TimeZone.getTimeZone(zoneId.ifEmpty { "UTC" })
    }
    val period = if (hourOf(ms, zoneId) < 12) "ص" else "م"
    return "${fmt.format(Date(ms))} $period"
  }

  private fun hijriDateString(
    cfg: Config,
    nowMs: Long,
    maghribMs: Long?
  ): String {
    // Uses android.icu (present on all supported APIs, minSdk 24) instead of
    // java.time, so no core-library desugaring is needed.
    // NOTE: Must use Umm al-Qura calculation to match the Flutter UI, which
    // uses the `hijri` Dart package (Umm al-Qura table). The ICU default is
    // the tabular civil calendar, which drifts 1-2 days from Umm al-Qura.
    return try {
      val tz = android.icu.util.TimeZone.getTimeZone(cfg.timezone.ifEmpty { "UTC" })
      val cal = android.icu.util.IslamicCalendar(
          tz, android.icu.util.ULocale.ENGLISH)
      cal.setCalculationType(
          android.icu.util.IslamicCalendar.CalculationType.ISLAMIC_UMALQURA)
      cal.timeInMillis = nowMs + cfg.hijriOffset * 86_400_000L
      if (maghribMs != null && nowMs >= maghribMs) {
        cal.add(android.icu.util.Calendar.DAY_OF_MONTH, 1)
      }
      val day = cal.get(android.icu.util.Calendar.DAY_OF_MONTH)
      val month = cal.get(android.icu.util.Calendar.MONTH) + 1 // 0-based
      val year = cal.get(android.icu.util.Calendar.YEAR)
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

  private fun hourOf(ms: Long, zoneId: String): Int {
    val cal = java.util.Calendar.getInstance(
        java.util.TimeZone.getTimeZone(zoneId.ifEmpty { "UTC" }))
    cal.timeInMillis = ms
    return cal.get(java.util.Calendar.HOUR_OF_DAY)
  }
}
