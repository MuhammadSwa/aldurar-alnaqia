import 'dart:async';

import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
import 'package:aldurar_alnaqia/models/consts/alhadra_collection.dart';
import 'package:aldurar_alnaqia/models/consts/azkar_morning_evening_collection.dart';
import 'package:aldurar_alnaqia/models/consts/ibn_ata_allah.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/widgets/azkarListView/azkar_list_view_widget.dart';
import 'package:aldurar_alnaqia/models/consts/ahzab_alshazly_collection.dart';
import 'package:aldurar_alnaqia/models/consts/azkar_algomari_collection.dart';
import 'package:aldurar_alnaqia/models/consts/chosen_salawat.dart';
import 'package:aldurar_alnaqia/models/consts/poems_collection.dart';
import 'package:aldurar_alnaqia/models/consts/salawat_yousria_collection.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/screens/prayer_timings_screen/prayer_timings_controller.dart'
    show PrayerTimeings, islamicWeekdayNow;

class DayAzkarList extends StatefulWidget {
  const DayAzkarList({
    super.key,
    required this.dayNum,
    required this.branch,
    required this.detailPagePrefix,
  });

  final int dayNum;
  final ZikrBranch branch;

  /// Route-name prefix of the nested zikr page this day's tiles open
  /// (differs between today's wird and the week-collection days).
  final String detailPagePrefix;

  @override
  State<DayAzkarList> createState() => _DayAzkarListState();
}

class _DayAzkarListState extends State<DayAzkarList> {
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
      // Titles + banner read prefs fresh on rebuild.
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // "Today" follows the Islamic day (which starts at Maghrib), matching
    // the day the home screen and todaysZikr route selected — otherwise the
    // Yousria wird would disappear between Maghrib and midnight.
    final bool isToday = widget.dayNum == islamicWeekdayNow();
    final titles = WeekCollectionAzkar.getDay(widget.dayNum, isToday: isToday);
    final listView = AzkarListViewWidget(
      titles: titles,
      barTitle: 'الأذكار',
      targetBuilder: (title, index) => ZikrDetailTarget(
        branch: widget.branch,
        title: title,
        pagePrefix: widget.detailPagePrefix,
        titles: titles,
        index: index,
      ),
    );

    final yousria = WeekCollectionAzkar.getYousriaDayInfo();

    // The banner shows on every day wird page until the user dismisses it.
    return Scaffold(
      appBar: AppBar(
        title: Text('ورد يوم ${arabicWeekdays[widget.dayNum - 1]}'),
      ),
      body: Column(
        children: [
          if (!_bannerDismissed)
            _YousriaBanner(
              yousria: yousria,
              onSetup: () => _openSetupSheet(yousria),
              onHide: _hideBanner,
            )
          else if (_showHideConfirmation)
            const _YousriaHideConfirmation(),
          Expanded(child: listView),
        ],
      ),
    );
  }
}

/// Which part of the 6-day Yousria cycle is read today.
class YousriaDayInfo {
  const YousriaDayInfo({
    required this.dayNumber,
    required this.title,
    required this.startDate,
  });

  /// 1..6
  final int dayNumber;
  final String title;
  final DateTime startDate;
}

class WeekCollectionAzkar {
  static final head = <String>[
    alwazifaZarouquia.title,
    almusabaeat.title,
    alasas.title,
  ];
  static final tail = <String>[
    alhyliaAndNasab.title,
    khitamFawatih.title,
  ];

  static final collection = <List<String>>[
    [hawatfAlhaqaeq.title, monagaIbnAtaAllah.title, hizbAlnasr.title],
    [hizbAlbar.title],
    [
      manzoumaAsmaaHosna.title,
      for (var i = 0; i < chosenSalawatCollection.length; i++)
        chosenSalawatCollection[i].title,
    ],
    [poemBordaBosiri.title],
    [
      alfathAlsedeqy.title,
      poemModaria.title,
      poemMohamadia.title,
      poemmadhWithQuarn.title
    ],
    [hizbAlbahr.title, hizbAlnawawi.title],
    [poemMonfarigaGazali.title, poemMonfarigaNahawi.title, poemBanatSuad.title],
  ];

  /// The civil date of the current *Islamic* day: between Maghrib and
  /// midnight the Islamic day has already advanced to tomorrow.
  static DateTime islamicEffectiveDate() {
    final now = DateTime.now();
    final maghrib = PrayerTimeings.getPrayersTimings()?.maghrib;
    if (maghrib != null && now.isAfter(maghrib)) {
      return now.add(const Duration(days: 1));
    }
    return now;
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Computes today's Yousria part (1..6) from the stored beginning day.
  /// Both dates are truncated to midnight so hours never shift the cycle,
  /// and the modulo is normalized so old beginnings wrap correctly.
  static YousriaDayInfo getYousriaDayInfo() {
    final startingDay = _midnight(SharedPreferencesService.getYousriaBeginning());
    final effectiveDay = _midnight(islamicEffectiveDate());
    final diff = effectiveDay.difference(startingDay).inDays;
    final dayNumber = (diff % 6 + 6) % 6 + 1;
    // salawatYousriaCollection: 0 intro, 1 asmaa, 2..7 day1..day6.
    final title = salawatYousriaCollection[dayNumber + 1].title;
    return YousriaDayInfo(
      dayNumber: dayNumber,
      title: title,
      startDate: startingDay,
    );
  }

  static List<String> getYousriaForToday() {
    return <String>[getYousriaDayInfo().title];
  }

  static List<String> getDay(int day, {required isToday}) {
    if (isToday) {
      return head + collection[day - 1] + getYousriaForToday() + tail;
    }
    return head + collection[day - 1] + tail;
  }
}

/// Educates about the 6-day Yousria cycle and offers one-tap setup.
/// Shown on every day wird page until dismissed.
class _YousriaBanner extends StatelessWidget {
  const _YousriaBanner({
    required this.yousria,
    required this.onSetup,
    required this.onHide,
  });

  final YousriaDayInfo yousria;
  final VoidCallback onSetup;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final startWeekday = arabicWeekdays[yousria.startDate.weekday - 1];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 20,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الصلوات اليسرية: ${yousria.title}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'تُقرأ على 6 أيام بالترتيب. حدّد متى قرأت الجزء الأول ليظهر لك جزء كل يوم.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'البداية الحالية: $startWeekday',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onHide,
                  child: const Text('إخفاء'),
                ),
                const SizedBox(width: 4),
                FilledButton.tonal(
                  onPressed: onSetup,
                  child: const Text('تحديد البداية'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Transient confirmation shown for a few seconds after the banner hides.
class _YousriaHideConfirmation extends StatelessWidget {
  const _YousriaHideConfirmation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم الإخفاء. يمكنك تغيير البداية لاحقًا من القائمة الجانبية.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet asking which part is read today.
/// Saving recalibrates the beginning so the cycle stays correct.
Future<bool?> showYousriaSetupSheet(
  BuildContext context,
  YousriaDayInfo current,
) {
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final effectiveMidnight = DateTime(
        WeekCollectionAzkar.islamicEffectiveDate().year,
        WeekCollectionAzkar.islamicEffectiveDate().month,
        WeekCollectionAzkar.islamicEffectiveDate().day,
      );
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(
                    'أي جزء تقرأ اليوم؟',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    'اختر جزء اليوم وسنحفظ بداية الدورة تلقائيًا.',
                  ),
                ),
                for (var day = 1; day <= 6; day++)
                  Builder(
                    builder: (context) {
                      // Choosing part [day] today means the cycle started
                      // (day - 1) days ago.
                      final impliedStart = effectiveMidnight
                          .subtract(Duration(days: day - 1));
                      final startWeekday =
                          arabicWeekdays[impliedStart.weekday - 1];
                      final title =
                          salawatYousriaCollection[day + 1].title;
                      final selected = day == current.dayNumber;
                      return ListTile(
                        title: Text(title),
                        subtitle: Text('البداية: $startWeekday'),
                        trailing: selected
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : const Icon(Icons.circle_outlined),
                        selected: selected,
                        onTap: () {
                          SharedPreferencesService.setYousriaBeginning(
                            impliedStart,
                          );
                          Navigator.of(sheetContext).pop(true);
                        },
                      );
                    },
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
    },
  );
}
