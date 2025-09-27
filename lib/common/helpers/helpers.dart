// TODO: use enums instead of strings

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

// Removed duplicate isFileDownloaded; use StorageService instead.
