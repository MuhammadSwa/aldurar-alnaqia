import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';

class YousriaBeginningDayDropDown extends StatefulWidget {
  const YousriaBeginningDayDropDown({super.key});

  @override
  State<YousriaBeginningDayDropDown> createState() =>
      _YousriaBeginningDayDropDownState();
}

class _YousriaBeginningDayDropDownState
    extends State<YousriaBeginningDayDropDown> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = _currentRelativeDay();
  }

  String araDayName(int relativeDayNum) {
    // relativeDayNum: today is zero, yesterday is 1 etc.

    int actualDayNum =
        DateTime.now().subtract(Duration(days: relativeDayNum)).weekday;
    return arabicWeekdays[actualDayNum - 1];
  }

  String _label(int i) {
    if (i == 0) {
      return 'اليوم (${araDayName(0)})';
    }
    return araDayName(i) == 'الجمعة'
        ? '${araDayName(i)} السابقة'
        : '${araDayName(i)} السابق';
  }

  int _currentRelativeDay() {
    final stored = SharedPreferencesService.getYousriaBeginning();
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final storedMidnight =
        DateTime(stored.year, stored.month, stored.day);
    final diff = todayMidnight.difference(storedMidnight).inDays;
    return diff.clamp(0, 5);
  }

  void _onSelected(int relativeDayNum) {
    final yousriaStartingDate =
        DateTime.now().subtract(Duration(days: relativeDayNum));
    SharedPreferencesService.setYousriaBeginning(yousriaStartingDate);
    setState(() {
      _selected = relativeDayNum;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: PopupMenuButton<int>(
          initialValue: _selected,
          position: PopupMenuPosition.under,
          onSelected: _onSelected,
          itemBuilder: (context) => [
            for (var i = 0; i < 6; i++)
              CheckedPopupMenuItem<int>(
                value: i,
                checked: i == _selected,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _label(i),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
          ],
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'بداية الصلوات اليسرية',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
