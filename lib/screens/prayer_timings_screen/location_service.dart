// services/location_service.dart
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Fetches the current geographical position.
  ///
  /// This method handles:
  /// 1. Checking if location services are enabled on the device.
  /// 2. Checking and requesting location permissions.
  /// 3. Fetching the current position.
  /// 4. Throws specific error messages that can be displayed to the user.
  static Future<({double latitude, double longitude})>
      getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      // Consider prompting the user to open location settings:
      // await Geolocator.openLocationSettings();
      return Future.error(
          'خدمة تحديد الموقع معطلة. يرجى تفعيلها من إعدادات الجهاز.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now).
        return Future.error(
            'تم رفض أذونات تحديد الموقع. لا يمكن جلب الموقع الحالي.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      // It's good practice to inform the user and guide them to app settings.
      // Consider prompting the user to open app settings:
      // await Geolocator.openAppSettings();
      return Future.error(
          'تم رفض أذونات تحديد الموقع بشكل دائم. يرجى تمكينها من إعدادات التطبيق.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            LocationAccuracy.medium, // .high can consume more battery
        // You can add a time limit if needed:
        // timeLimit: const Duration(seconds: 15),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } on PermissionDeniedException catch (e) {
      // This should ideally be caught by the checks above, but as a fallback.
      print(
          "Error fetching location (PermissionDeniedException): ${e.toString()}");
      return Future.error('تم رفض إذن تحديد الموقع بشكل غير متوقع.');
    } on LocationServiceDisabledException catch (e) {
      // This should ideally be caught by the serviceEnabled check, but as a fallback.
      print(
          "Error fetching location (LocationServiceDisabledException): ${e.toString()}");
      return Future.error('خدمة تحديد الموقع معطلة بشكل غير متوقع.');
    } catch (e) {
      // Catch any other unexpected errors during position fetching.
      print("Error fetching location: ${e.toString()}");
      return Future.error('حدث خطأ غير متوقع أثناء محاولة تحديد الموقع.');
    }
  }
}
