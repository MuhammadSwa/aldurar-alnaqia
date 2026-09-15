import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/setting_popup_tile.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class YousriaBeginningDayDropDown extends ConsumerWidget {
  const YousriaBeginningDayDropDown({super.key});

  static String araDayName(int relativeDayNum) {
    // relativeDayNum: today is zero, yesterday is 1 etc.
    final actualDayNum =
        DateTime.now().subtract(Duration(days: relativeDayNum)).weekday;
    return arabicWeekdays[actualDayNum - 1];
  }

  static String label(int i) {
    if (i == 0) {
      return 'اليوم (${araDayName(0)})';
    }
    return araDayName(i) == 'الجمعة'
        ? '${araDayName(i)} السابقة'
        : '${araDayName(i)} السابق';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(yousriaBeginningProvider.notifier).relativeDay();
    // Watch the date so the tile rebuilds when the setup sheet changes it.
    ref.watch(yousriaBeginningProvider);
    return SettingPopupTile<int>(
      title: 'بداية الصلوات اليسرية',
      value: selected,
      values: const [0, 1, 2, 3, 4, 5],
      labelFor: label,
      onSelected: (relativeDayNum) => ref
          .read(yousriaBeginningProvider.notifier)
          .setRelativeDay(relativeDayNum),
    );
  }
}
