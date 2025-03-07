import 'package:flutter/material.dart';
import 'package:yosria/common/helpers/helpers.dart';
import 'package:yosria/models/consts/alhadra_collection.dart';
import 'package:yosria/models/consts/azkar_morning_evening_collection.dart';
import 'package:yosria/models/consts/ibn_ataAllah.dart';
import 'package:yosria/widgets/azkarListView/azkarListView_widget.dart';
import 'package:yosria/models/consts/ahzab_alshazly_collection.dart';
import 'package:yosria/models/consts/azkar_algomari_collection.dart';
import 'package:yosria/models/consts/chosen_salawat.dart';
import 'package:yosria/models/consts/orphans.dart';
import 'package:yosria/models/consts/poems_collection.dart';
import 'package:yosria/models/consts/salawat_yousria_collection.dart';
import 'package:yosria/services/shared_prefs.dart';
import 'package:yosria/widgets/zikrSlider_screen.dart';
// TODO: instad of engDay make it numbers for previty and List

class DayAzkarList extends StatelessWidget {
  const DayAzkarList({
    super.key,
    required this.dayNum,
    // TODO: generate the route yourself
    // if today is true make it /home/todaysZikr/zikr
    required this.route,
  });

  final int dayNum;
  final String route;

  @override
  Widget build(BuildContext context) {
    final bool isToday = dayNum == DateTime.now().weekday;
    final titles = WeekCollectionAzkar.getDay(dayNum, isToday: isToday);
    return Scaffold(
      floatingActionButton: FloatingSliderBtn(titles: titles),
      appBar: AppBar(
        title: Text('ورد يوم ${arabicWeekdays[dayNum - 1]}'),
      ),
      body: AzkarListViewWidget(
        titles: titles,
        route: route,
        barTitle: 'الأذكار',
      ),
    );
  }
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
    [poemMonfarigaGazali.title, poemMonfarigaNahawi.title],
  ];

  static List<String> getYousriaForToday() {
    // TODO: in settings make user to chose startingDay
    final startingDay = SharedPreferencesService.getYousriaBeginning();
    final difference = (DateTime.now().difference(startingDay).inDays);
    final yousriaDay = (difference + 1) % 6;

    // this is the 6th day
    if (yousriaDay == 0) {
      return <String>[salawatYousriaCollection[7].title];
    }

    return <String>[salawatYousriaCollection[yousriaDay + 1].title];
  }

  static List<String> getDay(int day, {required isToday}) {
    if (isToday) {
      return head + collection[day - 1] + getYousriaForToday() + tail;
    }
    return head + collection[day - 1] + tail;
  }
}
