import 'dart:async';

import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
import 'package:aldurar_alnaqia/models/week_collection_data.dart';
import 'package:aldurar_alnaqia/prayer/prayer_repository.dart'
    show islamicWeekdayNow;
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/services/yousria_cycle.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/azkar_list_view_widget.dart';
import 'package:aldurar_alnaqia/widgets/yousria_banner.dart';
import 'package:aldurar_alnaqia/widgets/yousria_setup_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

export 'package:aldurar_alnaqia/models/week_collection_data.dart'
    show WeekCollectionAzkar;
export 'package:aldurar_alnaqia/services/yousria_cycle.dart'
    show YousriaDayInfo;

class DayAzkarList extends ConsumerStatefulWidget {
  const DayAzkarList({
    required this.dayNum, required this.branch, required this.detailPagePrefix, super.key,
  });

  final int dayNum;
  final ZikrBranch branch;

  /// Route-name prefix of the nested zikr page this day's tiles open
  /// (differs between today's wird and the week-collection days).
  final String detailPagePrefix;

  @override
  ConsumerState<DayAzkarList> createState() => _DayAzkarListState();
}

class _DayAzkarListState extends ConsumerState<DayAzkarList> {
  late bool _bannerDismissed;
  bool _showHideConfirmation = false;
  Timer? _confirmationTimer;

  @override
  void initState() {
    super.initState();
    _bannerDismissed = SharedPreferencesService.getYousriaBannerDismissed();
  }

  @override
  void dispose() {
    _confirmationTimer?.cancel();
    super.dispose();
  }

  Future<void> _hideBanner() async {
    await SharedPreferencesService.setYousriaBannerDismissed(true);
    if (!mounted) return;
    _confirmationTimer?.cancel();
    setState(() {
      _bannerDismissed = true;
      _showHideConfirmation = true;
    });
    _confirmationTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _showHideConfirmation = false);
    });
  }

  Future<void> _openSetupSheet(YousriaDayInfo current) async {
    final saved = await showYousriaSetupSheet(context, current);
    if (saved == true && mounted) {
      // Refresh the provider so the drawer dropdown stays in sync.
      ref.invalidate(yousriaBeginningProvider);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the beginning so setup-sheet and drawer changes rebuild us.
    ref.watch(yousriaBeginningProvider);
    // "Today" follows the Islamic day (which starts at Maghrib), matching
    // the day the home screen and todaysZikr route selected — otherwise the
    // Yousria wird would disappear between Maghrib and midnight.
    final isToday = widget.dayNum == islamicWeekdayNow();
    final zikrIds = WeekCollectionAzkar.getDay(widget.dayNum, isToday: isToday);
    final listView = AzkarListViewWidget(
      zikrIds: zikrIds,
      barTitle: 'الأذكار',
      targetBuilder: (zikrId, index) => ZikrDetailTarget(
        branch: widget.branch,
        zikrId: zikrId,
        pagePrefix: widget.detailPagePrefix,
        zikrIds: zikrIds,
        index: index,
      ),
    );

    final yousria = getYousriaDayInfo();

    // The banner shows on every day wird page until the user dismisses it.
    return Scaffold(
      appBar: AppBar(
        title: Text('ورد يوم ${arabicWeekdays[widget.dayNum - 1]}'),
      ),
      body: Column(
        children: [
          if (!_bannerDismissed)
            YousriaBanner(
              yousria: yousria,
              onSetup: () => _openSetupSheet(yousria),
              onHide: _hideBanner,
            )
          else if (_showHideConfirmation)
            const YousriaHideConfirmation(),
          Expanded(child: listView),
        ],
      ),
    );
  }
}
