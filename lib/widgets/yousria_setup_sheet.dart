import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/models/consts/salawat_yousria_collection.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/services/yousria_cycle.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

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
      final effectiveDate = islamicEffectiveDate();
      final effectiveMidnight = DateTime(
        effectiveDate.year,
        effectiveDate.month,
        effectiveDate.day,
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
                      final impliedStart =
                          effectiveMidnight.subtract(Duration(days: day - 1));
                      final title = yousriaDayZikr(day).title;
                      final selected = day == current.dayNumber;
                      return ListTile(
                        title: Text(title),
                        trailing: selected
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : const Icon(Icons.circle_outlined),
                        selected: selected,
                        onTap: () {
                          try {
                            ProviderScope.containerOf(context)
                                .read(yousriaBeginningProvider.notifier)
                                .setBeginning(impliedStart);
                          } catch (e) {
                            // Outside a ProviderScope (e.g. tests); persist
                            // directly so the choice isn't lost.
                            SharedPreferencesService.setYousriaBeginning(
                              impliedStart,
                            );
                          }
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
