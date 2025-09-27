// import 'dart:async';
// import 'dart:io';
// import 'dart:ui';
//
// import 'package:adhan/adhan.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// //
// class LocalNotificationService {
//   static final flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();
//
//   static onTap(NotificationResponse notificationResponse) {}
//
//   static Future init() async {
//     const settings = InitializationSettings(
//       android: AndroidInitializationSettings('@mipmap/ic_launcher'),
//       iOS: DarwinInitializationSettings(),
//       linux: LinuxInitializationSettings(defaultActionName: ''),
//     );
//
//     await flutterLocalNotificationsPlugin.initialize(
//       settings,
//       onDidReceiveNotificationResponse: onTap,
//       onDidReceiveBackgroundNotificationResponse: onTap,
//     );
//   }
//
//   static void basicNotification() async {
//     const androidNotificationDetails = AndroidNotificationDetails(
//       'channel id',
//       'channel name',
//       channelDescription: 'channel description',
//       importance: Importance.max,
//       priority: Priority.high,
//       ongoing: true,
//     );
//
//     await flutterLocalNotificationsPlugin.show(
//       0,
//       'عنوان الاشعار',
//       'محتوى الاشعار',
//       const NotificationDetails(
//         android: androidNotificationDetails,
//         iOS: DarwinNotificationDetails(),
//         linux: LinuxNotificationDetails(),
//       ),
//     );
//   }
// }
//
// @pragma('vm:entry-point')
// void onStart(ServiceInstance service) async {
//   DartPluginRegistrant.ensureInitialized();
//
//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();
//
//   if (service is AndroidServiceInstance) {
//     service.on('setAsForeground').listen((event) {
//       service.setAsForegroundService();
//     });
//
//     service.on('setAsBackground').listen((event) {
//       service.setAsBackgroundService();
//     });
//   }
//
//   service.on('stopService').listen((event) {
//     service.stopSelf();
//   });
//   Future<PrayerTimes>? getPrayersTimings() async {
//     final sharedPrefs = await SharedPreferences.getInstance();
//     Coordinates myCoordinates = Coordinates(
//       sharedPrefs.getDouble('latitude') ?? 0.0,
//       sharedPrefs.getDouble('longitude') ?? 0.0,
//     );
//
//     final method = sharedPrefs.getString('method') ?? 'egyptian';
//     final asrCalc = sharedPrefs.getString('asrCalculation') ?? 'shafi';
//
//     final CalculationParameters params;
//     switch (method) {
//       case 'egyptian':
//         params = CalculationMethod.egyptian.getParameters();
//         break;
//       case 'karachi':
//         params = CalculationMethod.karachi.getParameters();
//         break;
//       case 'muslim_world_league':
//         params = CalculationMethod.muslim_world_league.getParameters();
//         break;
//       case 'dubai':
//         params = CalculationMethod.dubai.getParameters();
//       case 'qatar':
//         params = CalculationMethod.qatar.getParameters();
//       case 'kuwait':
//         params = CalculationMethod.kuwait.getParameters();
//       case 'turkey':
//         params = CalculationMethod.turkey.getParameters();
//       case 'tehran':
//         params = CalculationMethod.tehran.getParameters();
//       case 'singapore':
//         params = CalculationMethod.singapore.getParameters();
//       case 'umm_al_qura':
//         params = CalculationMethod.umm_al_qura.getParameters();
//       case 'north_america':
//         params = CalculationMethod.north_america.getParameters();
//       case 'moon_sighting_committee':
//         params = CalculationMethod.moon_sighting_committee.getParameters();
//         break;
//       default:
//         params = CalculationMethod.other.getParameters();
//         break;
//     }
//
//     if (asrCalc == 'shafi') {
//       params.madhab = Madhab.shafi;
//     } else {
//       params.madhab = Madhab.hanafi;
//     }
//
//     return PrayerTimes.today(myCoordinates, params);
//   }
//
//   Future<String> timeLeftForNextPrayer() async {
//     final prayerTimes = await getPrayersTimings();
//     if (prayerTimes == null) {
//       return '00:00:00';
//     }
//
//     Prayer nextPrayer = prayerTimes.nextPrayer();
//     DateTime? nextPrayerTime = prayerTimes.timeForPrayer(nextPrayer);
//     if (nextPrayer == Prayer.none) {
//       nextPrayer = Prayer.fajr;
//       nextPrayerTime =
//           prayerTimes.timeForPrayer(nextPrayer)!.add(const Duration(days: 1));
//     }
//
//     final timeLeft =
//         nextPrayerTime!.difference(DateTime.now()).toString().split('.').first;
//
//     final String prayerName;
//     switch (prayerTimes.nextPrayer()) {
//       case Prayer.none:
//         prayerName = 'الفجر';
//         break;
//       case Prayer.fajr:
//         prayerName = 'الفجر';
//         break;
//       case Prayer.sunrise:
//         prayerName = 'الشروق';
//         break;
//       case Prayer.dhuhr:
//         prayerName = 'الظهر';
//         break;
//       case Prayer.asr:
//         prayerName = 'العصر';
//         break;
//       case Prayer.maghrib:
//         prayerName = 'المغرب';
//         break;
//       case Prayer.isha:
//         prayerName = 'العشاء';
//         break;
//     }
//     return '$prayerName بعد $timeLeft';
//   }
//
//   // bring to foreground
//   Timer.periodic(const Duration(seconds: 1), (timer) async {
//     String timeLeft = await timeLeftForNextPrayer();
//     if (service is AndroidServiceInstance) {
//       if (await service.isForegroundService()) {
//         /// OPTIONAL for use custom notification
//         /// the notification id must be equals with AndroidConfiguration when you call configure() method.
//         flutterLocalNotificationsPlugin.show(
//           888,
//           'prayer timings',
//           timeLeft,
//           const NotificationDetails(
//             android: AndroidNotificationDetails(
//               'my_foreground',
//               'MY FOREGROUND SERVICE',
//               icon: 'ic_bg_service_small',
//               ongoing: true,
//             ),
//           ),
//         );
//         service.setForegroundNotificationInfo(
//           title: "مواقيت الصلاة",
//           content: timeLeft,
//         );
//       }
//     }
//
//     /// you can see this log in logcat
//     print('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');
//   });
// }
//
// Future<void> initializeService() async {
//   final service = FlutterBackgroundService();
//   const AndroidNotificationChannel channel = AndroidNotificationChannel(
//     'my_foreground', // id
//     'MY FOREGROUND SERVICE', // title
//     description:
//         'This channel is used for important notifications.', // description
//     importance: Importance.low, // importance must be at low or higher level
//   );
//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();
//
//   if (Platform.isIOS || Platform.isAndroid) {
//     await flutterLocalNotificationsPlugin.initialize(
//       const InitializationSettings(
//         iOS: DarwinInitializationSettings(),
//         android: AndroidInitializationSettings('ic_bg_service_small'),
//       ),
//     );
//   }
//
//   await flutterLocalNotificationsPlugin
//       .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin>()
//       ?.createNotificationChannel(channel);
//
//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       // this will be executed when app is in foreground or background in separated isolate
//       onStart: onStart,
//
//       // auto start service
//       autoStart: true,
//       isForegroundMode: true,
//
//       notificationChannelId: 'my_foreground',
//       initialNotificationTitle: 'AWESOME SERVICE',
//       initialNotificationContent: 'Initializing',
//       foregroundServiceNotificationId: 888,
//     ),
//     iosConfiguration: IosConfiguration(
//       // auto start service
//       autoStart: true,
//
//       // this will be executed when app is in foreground in separated isolate
//       onForeground: onStart,
//       // you have to enable background fetch capability on xcode project
//     ),
//   );
// }
