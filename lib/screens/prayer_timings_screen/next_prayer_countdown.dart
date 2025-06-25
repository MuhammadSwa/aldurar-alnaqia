import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NextPrayerCountdown extends StatelessWidget {
  const NextPrayerCountdown({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100, // Fixed height
      child: Card(
        elevation: 4,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: GetX<PrayerTimingsController>(
              builder: (controller) {
                if (!controller.isInitialized.value) {
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('جاري تحميل أوقات الصلاة...'),
                    ],
                  );
                }

                final timeLeft = controller.timeLeftForNextPrayer.value.$1;
                final prayerName = controller.timeLeftForNextPrayer.value.$2;

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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'بعد ${_formatDuration(timeLeft)}',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return "00:00:00";
    }
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return "${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}";
  }
}
