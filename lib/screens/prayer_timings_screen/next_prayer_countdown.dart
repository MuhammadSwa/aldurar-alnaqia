import 'dart:async';

import 'package:aldurar_alnaqia/prayer/prayer_providers.dart';
import 'package:aldurar_alnaqia/prayer/prayer_repository.dart';
import 'package:aldurar_alnaqia/prayer/prayer_schedule.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_settings_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:timezone/timezone.dart' as tz;

/// Countdown to the next prayer.
///
/// Owns its own 1-second [Timer] while mounted: navigating away disposes it,
/// so no Dart wakeups happen while the user reads elsewhere. The displayed
/// next prayer is derived live on every tick from the cached daily schedule
/// and wall-clock time — nothing about "now" is stored, so manual
/// system-clock changes correct themselves within a second with no refresh
/// protocol. When the derived next prayer differs from the last published
/// one, the tick pokes [prayerNudgeProvider] so highlight/weekday/date
/// widgets rebuild too.
class NextPrayerCountdown extends ConsumerStatefulWidget {
  const NextPrayerCountdown({super.key});

  @override
  ConsumerState<NextPrayerCountdown> createState() =>
      _NextPrayerCountdownState();
}

class _NextPrayerCountdownState extends ConsumerState<NextPrayerCountdown> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  /// Epoch-ms of the next event we last poked for. Change detection only —
  /// the display always uses the live derivation in [build].
  int? _pokedFor;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final view = ref.read(prayerViewProvider);
    // Unconfigured: nothing to count toward. The `watch` in `build`
    // rebuilds us when settings get published — no ticking needed.
    if (view == null) return;
    final now = DateTime.now();
    // The repository is a stateless cache, not a provider: read the shared
    // instance directly. Display values are derived here, never subscribed.
    final epoch = PrayerRepository.instance
        .nextAt(view.settings, now)
        ?.time
        .millisecondsSinceEpoch;
    if (epoch != _pokedFor) {
      _pokedFor = epoch;
      ref.read(prayerNudgeProvider.notifier).poke();
    }
    setState(() => _now = now);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final view = ref.watch(prayerViewProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: view == null
          ? _UnsetContent(onTap: () => _openSettings(context))
          : Builder(
              builder: (context) {
                // Live derivation, deliberately `read` (not `watch`): this
                // rebuild already runs every tick and on every nudge, so
                // subscribing would add nothing but rebuild loops.
                final next = PrayerRepository.instance.nextAt(
                  view.settings,
                  _now,
                );
                if (next == null) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LocationLine(
                        label: view.cityLabel,
                        isUnset: view.cityLabel.isEmpty,
                        onTap: () => _openSettings(context),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'خطأ في حساب أوقات الصلاة',
                        style: TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }
                // `next` is strictly after `_now` by construction
                // (`nextAt` returns the first event after now), so this stays
                // positive through the midnight→Fajr window. Clamped
                // defensively so a clock jump can never render negative.
                final rawLeft = next.time.difference(_now);
                final left =
                    rawLeft.isNegative ? Duration.zero : rawLeft;
                final liveSchedule = PrayerRepository.instance.scheduleFor(
                      view.settings,
                      _now,
                    ) ??
                    view.schedule;
                final progress = _progress(
                  settings: view.settings,
                  schedule: liveSchedule,
                  now: _now,
                  next: next,
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LocationLine(
                      label: view.cityLabel,
                      isUnset: view.cityLabel.isEmpty,
                      onTap: () => _openSettings(context),
                    ),
                    const SizedBox(height: 6),
                    // Next-prayer hero: name + countdown in one line.
                    // No clock icon: the countdown digits already say that.
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          '${next.arabicName} بعد',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                          ),
                          child: Text(
                            _formatDuration(left),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ],
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final marker = _markerFor(next.id);
                              final dx = constraints.maxWidth * progress;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(99),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 4,
                                        backgroundColor: colorScheme.primary
                                            .withValues(alpha: 0.15),
                                      ),
                                    ),
                                  ),
                                  // Opaque next-prayer icon riding the
                                  // fill tip. RTL: measure from the right.
                                  Positioned(
                                    right: (dx - 9).clamp(
                                      0.0,
                                      constraints.maxWidth - 18,
                                    ),
                                    top: -2,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: marker.color,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        marker.icon,
                                        size: 10,
                                        color: Colors.white,
                                        semanticLabel: next.arabicName,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  void _openSettings(BuildContext context) {
    showDialog(context: context, builder: (_) => const PrayerSettingsDialog());
  }

  /// Opaque marker for the bar's fill tip: the next prayer's timetable
  /// icon in its timetable tint, mirroring [PrayerTimingsCard].
  ({IconData icon, Color color}) _markerFor(PrayerEventId id) => switch (id) {
        PrayerEventId.fajr => (
            icon: LucideIcons.sunMoon,
            color: const Color(0xFF7C6AAE),
          ),
        PrayerEventId.sunrise => (
            icon: LucideIcons.sunrise,
            color: const Color(0xFFE8823A),
          ),
        PrayerEventId.dhuhr => (
            icon: LucideIcons.sun,
            color: const Color(0xFFB8860B),
          ),
        PrayerEventId.asr => (
            icon: LucideIcons.cloudSun,
            color: const Color(0xFFD97A2B),
          ),
        PrayerEventId.maghrib => (
            icon: LucideIcons.sunset,
            color: const Color(0xFFC14A3A),
          ),
        PrayerEventId.isha => (
            icon: LucideIcons.moon,
            color: const Color(0xFF4A5AA8),
          ),
      };

  /// Elapsed fraction from the previous event to [next] (0–1). Before
  /// today's Fajr the previous event is yesterday's Isha, so the bar keeps
  /// moving through the midnight→Fajr window instead of hiding. Null only
  /// when no previous event can be determined. Ticks with [_now], so the
  /// bar under the counter moves every second.
  double? _progress({
    required PrayerSettings settings,
    required PrayerSchedule schedule,
    required DateTime now,
    required PrayerEvent next,
  }) {
    final location = schedule.civilDate.location;
    final zonedNow = tz.TZDateTime.from(now, location);
    // Overnight window (before today's Fajr): pull yesterday's schedule
    // so "previous" resolves to yesterday's Isha. Cached after the first
    // tick of the night — one solar calculation per night, then map hits.
    PrayerSchedule? yesterday;
    if (schedule.ordered.every((event) => event.time.isAfter(zonedNow))) {
      yesterday = PrayerRepository.instance.scheduleFor(
        settings,
        tz.TZDateTime(
          location,
          zonedNow.year,
          zonedNow.month,
          zonedNow.day - 1,
          12,
        ),
      );
    }
    final prev = progressIntervalStart(
      schedule: schedule,
      yesterdaySchedule: yesterday,
      now: zonedNow,
    );
    if (prev == null) return null;
    final prevMs = prev.millisecondsSinceEpoch;
    final nextMs = next.time.millisecondsSinceEpoch;
    if (nextMs <= prevMs) return null;
    final nowMs = zonedNow.millisecondsSinceEpoch;
    if (nowMs < prevMs) return null;
    return ((nowMs - prevMs) / (nextMs - prevMs)).clamp(0.0, 1.0);
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return '00:00:00';
    }
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

/// Start of the countdown interval: the latest event in [schedule] at or
/// before [now], or — when [now] is before today's Fajr (the midnight→Fajr
/// window) — yesterday's Isha from [yesterdaySchedule]. Null only when
/// neither exists. Pure (no clock/cache reads) so the overnight case is
/// unit-testable; the widget resolves [yesterdaySchedule] via the
/// repository cache.
@visibleForTesting
tz.TZDateTime? progressIntervalStart({
  required PrayerSchedule schedule,
  required PrayerSchedule? yesterdaySchedule,
  required tz.TZDateTime now,
}) {
  tz.TZDateTime? prev;
  for (final event in schedule.ordered) {
    if (!event.time.isAfter(now)) {
      prev = event.time;
    }
  }
  return prev ?? yesterdaySchedule?.events[PrayerEventId.isha]?.time;
}

class _UnsetContent extends StatelessWidget {
  final VoidCallback onTap;

  const _UnsetContent({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LocationLine(label: '', isUnset: true, onTap: onTap),
        const SizedBox(height: 4),
        const Text(
          'اضغط لتحديد الموقع لحساب المواقيت',
          style: TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Tappable location line shown above the countdown.
/// Unset state invites the user to pick a location.
class _LocationLine extends StatelessWidget {
  final String label;
  final bool isUnset;
  final VoidCallback onTap;

  const _LocationLine({
    required this.label,
    required this.isUnset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUnset
                  ? Icons.location_off_outlined
                  : Icons.location_on_outlined,
              size: 14,
              color: isUnset ? theme.hintColor : theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                isUnset ? 'اضغط لتحديد الموقع' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isUnset
                      ? theme.hintColor
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
