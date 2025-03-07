// TODO: use enums instead of strings
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum Day { sat, sun, mon, tue, wed, thu, fri }

// num,ara - 7: الأحد
int todaysNum() {
  return DateTime.now().weekday;
}

const arabicWeekdays = <String>[
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

// TODO: use only one isFileDownloaded
Future<bool> isFileDownloaded(
    {required String title, required directory}) async {
  final String extension = directory == 'narrations' ? 'mp3' : 'pdf';
  // late String supportDir;
  final String supportDir = await () async {
    final Directory dir;
    dir = await getApplicationSupportDirectory();
    return dir.path;
  }();

  final path = '$supportDir/$directory/$title.$extension';

  File file = File(path);

  if (file.existsSync()) {
    return true;
  } else {
    return false;
  }
}


