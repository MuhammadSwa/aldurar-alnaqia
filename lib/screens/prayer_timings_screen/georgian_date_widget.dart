import 'dart:async';

import 'package:aldurar_alnaqia/common/widgets/inline_text.dart';
import 'package:flutter/material.dart';

class GeorgianDateWidget extends StatefulWidget {
  const GeorgianDateWidget({super.key});

  @override
  State<GeorgianDateWidget> createState() => _GeorgianDateWidgetState();
}

class _GeorgianDateWidgetState extends State<GeorgianDateWidget> {
  late DateTime _currentDate;
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
    _currentDate = DateTime.now();
    _scheduleNextUpdate();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Important: prevent memory leaks
    super.dispose();
  }

  void _scheduleNextUpdate() {
    final now = DateTime.now();
    // Calculate the exact moment of the next midnight.
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = nextMidnight.difference(now);

    // Set a timer that will fire only once, precisely at midnight.
    _timer = Timer(durationUntilMidnight, () {
      if (mounted) {
        setState(() {
          _currentDate = DateTime.now();
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
