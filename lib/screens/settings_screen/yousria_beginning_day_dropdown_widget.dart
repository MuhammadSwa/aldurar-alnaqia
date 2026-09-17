import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/common/widgets/settings_card.dart'; // <-- add this
import 'package:aldurar_alnaqia/models/consts/salawat_yousria_collection.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/setting_popup_tile.dart';
import 'package:aldurar_alnaqia/services/yousria_cycle.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

/// Settings tile showing the current Yousria cycle day (1..6).
///
/// Reads through [getYousriaDayInfo] — the same path the home banner uses —
/// and writes via [impliedStartForDay] — the same math the setup sheet uses —
/// so all three surfaces can never disagree.
class YousriaBeginningDayDropDown extends ConsumerWidget {
  const YousriaBeginningDayDropDown({
    super.key,
    this.cardStyle = SettingsCardStyle.classic,
  });

  final SettingsCardStyle cardStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider so the tile rebuilds when the beginning changes
    // (from this dropdown or the banner's setup sheet).
    ref.watch(yousriaBeginningProvider);

    // Same read path as the banner — cannot be off by one.
    final currentDay = getYousriaDayInfo().dayNumber;

    return SettingPopupTile<int>(
      title: 'يوم الصلوات اليسرية',
      value: currentDay,
      values: const [1, 2, 3, 4, 5, 6],
      labelFor: (day) => yousriaDayZikr(day).title,
      cardStyle: cardStyle,
      onSelected: (day) => ref
          .read(yousriaBeginningProvider.notifier)
          .setBeginning(impliedStartForDay(day)),
    );
  }
}
