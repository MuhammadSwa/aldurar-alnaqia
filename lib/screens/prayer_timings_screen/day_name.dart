// Pure renderer of the provider's Islamic weekday: rebuilds only when the
// weekday itself changes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart';

class ArabicDayNameWidget extends ConsumerWidget {
  const ArabicDayNameWidget({super.key});

  static const Map<int, String> _arabicDayNames = {
    7: 'الأحد',
    1: 'الإثنين',
    2: 'الثلاثاء',
    3: 'الأربعاء',
    4: 'الخميس',
    5: 'الجمعة',
    6: 'السبت',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInitialized =
        ref.watch(prayerProvider.select((s) => s.isInitialized));
    final weekday =
        ref.watch(prayerProvider.select((s) => s.islamicWeekday));

    if (!isInitialized) {
      return const SizedBox(
        height: 120, // Same height as NextPrayerCountdown
        child: Card(
          elevation: 4,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return SizedBox(
      height: 100, // Fixed height to match NextPrayerCountdown
      child: Card(
        elevation: 4,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Text(
              _arabicDayNames[weekday] ?? '...',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 30,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
