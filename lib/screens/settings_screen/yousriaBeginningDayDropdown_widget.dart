import 'package:flutter/material.dart';
import 'package:aldurar_alnaqia/common/helpers/helpers.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';

class YousriaBeginningDayDropDown extends StatelessWidget {
  const YousriaBeginningDayDropDown({super.key});

  String araDayName(int relativeDayNum) {
    // relativeDayNum: today is zero, yesterday is 1 etc.

    int actualDayNum =
        DateTime.now().subtract(Duration(days: relativeDayNum)).weekday;
    return arabicWeekdays[actualDayNum - 1];
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        // TODO: make value the beginning day name from shared_prefs
        // value: 0,
        hint: const Text(
          'بداية الصلوات اليسرية',
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Colors.grey,
        ),
        isExpanded: true,
        style: const TextStyle(
          // color: Colors.black87,
          fontSize: 16,
        ),
        // dropdownColor: Colors.white,
        // borderRadius: BorderRadius.circular(12),
        // elevation: 8,
        items: <DropdownMenuItem<int>>[
          for (var i = 0; i < 6; i++)
            if (i == 0) ...{
              DropdownMenuItem(
                alignment: Alignment.centerRight,
                value: 0,
                child: Text(
                  'اليوم (${araDayName(0)})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            } else ...{
              DropdownMenuItem(
                alignment: Alignment.centerRight,
                value: i,
                child: araDayName(i) == 'الجمعة'
                    ? Text(
                        '${araDayName(i)} السابقة',
                        style: Theme.of(context).textTheme.titleMedium,
                      )
                    : Text(
                        '${araDayName(i)} السابق',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
              )
            }
        ],
        onChanged: (relativeDayNum) {
          // relativeDayNum: today is zero, yesterday is 1 etc.

          final yousriaStartingDate =
              DateTime.now().subtract(Duration(days: relativeDayNum!));
          SharedPreferencesService.setYousriaBeginning(yousriaStartingDate);
        },
      ),
    );
  }
}

// class YousriaBeginningDayDropDown extends StatelessWidget {
//   const YousriaBeginningDayDropDown({super.key});
//
//   String araDayName(int relativeDayNum) {
//     // relativeDayNum: today is zero, yesterday is 1 etc.
//
//     int actualDayNum =
//         DateTime.now().subtract(Duration(days: relativeDayNum)).weekday;
//     return arabicWeekdays[actualDayNum - 1];
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return DropdownButton(
//       // TODO: make value the beginning day name from shared_prefs
//       // value: 0,
//       hint: const Text('اختر يوم'),
//       items: <DropdownMenuItem<int>>[
//         for (var i = 0; i < 6; i++)
//           if (i == 0) ...{
//             DropdownMenuItem(
//               alignment: Alignment.centerRight,
//               value: 0,
//               child: Text('اليوم (${araDayName(0)})'),
//             ),
//           } else ...{
//             DropdownMenuItem(
//               alignment: Alignment.centerRight,
//               value: i,
//               child: araDayName(i) == 'الجمعة'
//                   ? Text('${araDayName(i)} السابقة')
//                   : Text('${araDayName(i)} السابق'),
//             )
//           }
//       ],
//       onChanged: (relativeDayNum) {
//         // relativeDayNum: today is zero, yesterday is 1 etc.
//
//         final yousriaStartingDate =
//             DateTime.now().subtract(Duration(days: relativeDayNum!));
//         SharedPreferencesService.setYousriaBeginning(yousriaStartingDate);
//       },
//     );
//   }
// }
