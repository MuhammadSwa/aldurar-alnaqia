import 'dart:async';

import 'package:aldurar_alnaqia/common/widgets/inline_text.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

class GregorianDateWidget extends StatefulWidget {
  const GregorianDateWidget({super.key});

  @override
  State<GregorianDateWidget> createState() => _GregorianDateWidgetState();
}

class _GregorianDateWidgetState extends State<GregorianDateWidget> {
  late tz.TZDateTime _currentDate;
  Timer? _timer;

  static const Map<int, String> _arabicMonths = {
    1: 'يناير',
    2: 'فبراير',
    3: 'مارس',
    4: 'أبريل',
    5: 'مايو',
    6: 'يونيو',
    7: 'يوليو',
    8: 'أغسطس',
    9: 'سبتمبر',
    10: 'أكتوبر',
    11: 'نوفمبر',
    12: 'ديسمبر',
  };

  @override
  void initState() {
    super.initState();
    _currentDate = tz.TZDateTime.now(tz.local);
    _scheduleNextUpdate();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Important: prevent memory leaks
    super.dispose();
  }

  void _scheduleNextUpdate() {
    final now = tz.TZDateTime.now(tz.local);
    // Calculate the exact moment of the next midnight.
    final nextMidnight =
        tz.TZDateTime(tz.local, now.year, now.month, now.day + 1);
    final durationUntilMidnight = nextMidnight.difference(now);

    // Set a timer that will fire only once, precisely at midnight.
    _timer = Timer(durationUntilMidnight, () {
      if (mounted) {
        setState(() {
          _currentDate = tz.TZDateTime.now(tz.local);
        });
        // After updating, schedule the *next* update for the following midnight.
        _scheduleNextUpdate();
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_arabicMonths[date.month]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InlineTextWidget(
      style: Theme.of(context).textTheme.titleMedium,
      _formatDate(_currentDate),
      textDirection: TextDirection.rtl,
    );
  }
}
