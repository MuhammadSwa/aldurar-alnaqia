import 'dart:async';

import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Countdown to the next prayer.
///
/// Owns its own 1-second [Timer] while mounted: navigating away disposes it,
/// so no Dart wakeups happen while the user reads elsewhere. The global
/// prayer state only changes at event boundaries; this widget diffs the
/// cached target against `now` locally and asks the notifier to refresh when
/// the target is long past (e.g. the device slept through a boundary).
class NextPrayerCountdown extends ConsumerStatefulWidget {
  const NextPrayerCountdown({super.key});

  @override
  ConsumerState<NextPrayerCountdown> createState() =>
      _NextPrayerCountdownState();
}

class _NextPrayerCountdownState extends ConsumerState<NextPrayerCountdown> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  /// Target the local ticker is currently counting toward. Re-synced from
  /// the provider on every tick (no `ref.listen` needed — the 1s cadence
  /// picks up boundary/settings changes within a second).
  DateTime? _target;

  @override
  void initState() {
    super.initState();
    _target = ref.read(prayerProvider).nextPrayerInfo.$1;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_target == null) return;
    _tick();
    // Align ticks to the wall-clock second to avoid drift.
    final now = DateTime.now();
    final toNextSecond =
        Duration(milliseconds: 1000 - now.millisecond) + const Duration(milliseconds: 50);
    _timer = Timer(toNextSecond, () {
      if (!mounted) return;
      _tick();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        _tick();
      });
    });
  }

  void _tick() {
    if (!mounted) return;
    final latest = ref.read(prayerProvider).nextPrayerInfo.$1;
    if (latest != _target) {
      // Boundary or settings change: restart toward the new target.
      _target = latest;
      _startTimer();
      return;
    }
    final target = _target;
    if (target == null) return;
    final left = target.difference(DateTime.now());
    if (left.inSeconds < -5) {
      // Boundary was missed (sleep/suspend): let the single owner recalc.
      ref.read(prayerProvider.notifier).refresh();
      return;
    }
    setState(() {
      _timeLeft = left.isNegative ? Duration.zero : left;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isInitialized =
        ref.watch(prayerProvider.select((s) => s.isInitialized));
    final next = ref.watch(prayerProvider.select((s) => s.nextPrayerInfo));

    // The ticker re-syncs only while it runs. If the target appeared while
    // it was idle (first setup: null → first prayer), (re)start it. The
    // field write here is safe; timer work is deferred past build.
    if (next.$1 != _target) {
      if (next.$1 == null) {
        _target = null;
        _timer?.cancel();
      } else {
        _target = next.$1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startTimer();
        });
      }
    }

    return SizedBox(
      height: 100, // Fixed height
      child: Card(
        elevation: 4,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: !isInitialized
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('جاري تحميل أوقات الصلاة...'),
                    ],
                  )
                : Builder(builder: (context) {
                    final prayerName = next.$2;

                    if (prayerName.isEmpty) {
                      return const Text(
                        'خطأ في حساب أوقات الصلاة',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      );
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          prayerName,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'بعد ${_formatDuration(_timeLeft)}',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },),
          ),
        ),
      ),
    );
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
