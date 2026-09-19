import 'package:aldurar_alnaqia/prayer/prayer_hijri.dart';
import 'package:material_ui/material_ui.dart';

/// Hijri date label. Stateless renderer: the caller passes wall-clock time,
/// the Maghrib boundary, and the manual day offset; rendering goes through
/// the shared [hijriLabel] helper (same source as the native payload).
class HijriDateWidget extends StatelessWidget {
  final DateTime now;
  final DateTime? maghrib;
  final int offset;

  const HijriDateWidget({
    super.key,
    required this.now,
    required this.maghrib,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      hijriLabel(now: now, maghrib: maghrib, offset: offset),
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
