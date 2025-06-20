import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayerTimingsController.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NextPrayerCountdown extends StatelessWidget {
  const NextPrayerCountdown({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GetX<PrayerTimingsController>(
          builder: (controller) {
            // Show loading state while initializing
            if (!controller.isInitialized.value) {
              return const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('جاري تحميل أوقات الصلاة...'),
                ],
              );
            }

            // Check if prayer timings are available
            if (controller.prayerTimings == null) {
              return const Text(
                'برجاء تحديد الموقع أولاً',
                style: TextStyle(fontSize: 16),
              );
            }

            // Get current countdown values
            final timeLeft = controller.timeLeftForNextPrayer.value.$1;
            final prayerName = controller.timeLeftForNextPrayer.value.$2;

            // Handle edge case where prayer name is empty
            if (prayerName.isEmpty) {
              return const Text(
                'خطأ في حساب أوقات الصلاة',
                style: TextStyle(fontSize: 16),
              );
            }

            return Column(
              children: [
                Text(
                  prayerName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'بعد ${_formatDuration(timeLeft)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    // Handle negative durations (shouldn't happen, but safety first)
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
