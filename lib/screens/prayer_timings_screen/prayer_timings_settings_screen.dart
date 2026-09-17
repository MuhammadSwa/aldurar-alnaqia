import 'package:aldurar_alnaqia/screens/prayer_timings_screen/hijri_adjust_form.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_settings_form.dart';
import 'package:flutter/material.dart';

/// Settings page for the prayer timings screen.
///
/// Hijri adjustment on top, prayer-timing settings under it.
/// Opened from the AppBar settings icon; the dialogs stay untouched
/// for the auto-setup prompt and other callers.
class PrayerTimingsSettingsScreen extends StatelessWidget {
  const PrayerTimingsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Hijri adjustment (on top) ----
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'تعديل اليوم الهجري',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const HijriAdjustForm(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ---- Prayer timings settings (under it) ----
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.settings,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'إعدادات مواقيت الصلاة',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const PrayerSettingsForm(showCancel: false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
