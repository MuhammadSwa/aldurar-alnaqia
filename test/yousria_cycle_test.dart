import 'package:aldurar_alnaqia/models/week_collection_data.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/services/yousria_cycle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the 6-day Yousria cycle. Location prefs stay empty, so
/// [todayPrayerSchedule] returns null and the Islamic effective day is the
/// civil day — making the cycle fully deterministic from the stored
/// beginning day.
void main() {
  DateTime midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferencesService().init();
  });

  group('getYousriaDayInfo', () {
    test('a beginning of today is day 1', () {
      SharedPreferencesService.setYousriaBeginning(DateTime.now());
      final info = getYousriaDayInfo();
      expect(info.dayNumber, 1);
      expect(info.zikrId, 'yousria-day-1');
      expect(info.title, isNotEmpty);
      expect(info.startDate, midnight(DateTime.now()));
    });

    test('each elapsed day advances the cycle', () {
      for (var ago = 0; ago < 6; ago++) {
        SharedPreferencesService.setYousriaBeginning(
          DateTime.now().subtract(Duration(days: ago)),
        );
        expect(getYousriaDayInfo().dayNumber, ago + 1);
      }
    });

    test('the cycle wraps after 6 days', () {
      SharedPreferencesService.setYousriaBeginning(
        DateTime.now().subtract(const Duration(days: 6)),
      );
      expect(getYousriaDayInfo().dayNumber, 1);

      SharedPreferencesService.setYousriaBeginning(
        DateTime.now().subtract(const Duration(days: 7)),
      );
      expect(getYousriaDayInfo().dayNumber, 2);
    });

    test('a future beginning wraps instead of going negative', () {
      SharedPreferencesService.setYousriaBeginning(
        DateTime.now().add(const Duration(days: 1)),
      );
      expect(getYousriaDayInfo().dayNumber, 6);
    });

    test('hours within a day never shift the cycle', () {
      final now = DateTime.now();
      SharedPreferencesService.setYousriaBeginning(
        DateTime(now.year, now.month, now.day, 23, 59),
      );
      expect(getYousriaDayInfo().dayNumber, 1);
    });
  });

  group('getYousriaForToday', () {
    test('returns exactly the current part id', () {
      SharedPreferencesService.setYousriaBeginning(DateTime.now());
      expect(getYousriaForToday(), ['yousria-day-1']);
    });
  });

  group('WeekCollectionAzkar.getDay', () {
    test('non-today days wrap in head and tail without Yousria', () {
      final monday = WeekCollectionAzkar.getDay(1, isToday: false);
      expect(
        monday.take(3),
        ['wazifa-zarouqiyya', 'musabbaat-ashr', 'wird-asas'],
      );
      expect(monday.sublist(monday.length - 2), ['hilya-nasab', 'khitam-fawatih']);
      expect(monday, contains('hawatif-haqaiq'));
      expect(monday, isNot(contains('yousria-day-1')));
    });

    test('all 7 days resolve to non-empty lists', () {
      for (var day = 1; day <= 7; day++) {
        expect(
          WeekCollectionAzkar.getDay(day, isToday: false),
          isNotEmpty,
          reason: 'day $day must not be empty',
        );
      }
    });

    test('today injects the current Yousria part before the tail', () {
      SharedPreferencesService.setYousriaBeginning(DateTime.now());
      final today = WeekCollectionAzkar.getDay(1, isToday: true);
      final yousriaIndex = today.indexOf('yousria-day-1');
      expect(yousriaIndex, isNot(-1));
      expect(
        today.sublist(yousriaIndex),
        ['yousria-day-1', 'hilya-nasab', 'khitam-fawatih'],
      );
    });
  });
}
