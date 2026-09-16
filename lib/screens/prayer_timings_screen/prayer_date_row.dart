import 'package:aldurar_alnaqia/screens/prayer_timings_screen/gregorian_date_widget.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/hijri_date_widget.dart';
import 'package:flutter/material.dart';

class PrayerDateRow extends StatelessWidget {
  const PrayerDateRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                child: HijriDateWidget(),
              ),
            ),
          ),
        ),
        SizedBox(width: 6),
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                // Use our new, efficient Gregorian Date widget.
                child: GregorianDateWidget(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
