import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:universal_platform/universal_platform.dart';

/// Determines the current position of the device.
///
/// When the location services are not enabled or permissions
/// are denied the `Future` will return an error.
Future<Position> determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled on the device.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled. Don't continue
    // accessing the position and request users to enable the services.
    // This will be caught by the UI and prompt the user to open settings.
    return Future.error(const LocationServiceDisabledException());
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true). According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error(
          const PermissionDeniedException('Location permissions are denied'));
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    // The UI will have to guide the user to the app settings.
    return Future.error(const PermissionDeniedException(
        'Location permissions are permanently denied, we cannot request permissions.'));
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition();
}

class LocationButtonWidget extends StatefulWidget {
  const LocationButtonWidget({super.key, required this.onGettingLocation});
  final Function({required String latitude, required String longitude})
      onGettingLocation;
  @override
  State<LocationButtonWidget> createState() => _LocationButtonWidgetState();
}

class _LocationButtonWidgetState extends State<LocationButtonWidget> {
  void getLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final position = await determinePosition();
      widget.onGettingLocation(
        latitude: position.latitude.toString(),
        longitude: position.longitude.toString(),
      );
    } catch (error) {
      // Case 1: The device's location service is turned off.
      if (error is LocationServiceDisabledException) {
        // Show a dialog that asks the user to enable location and provides a button to open settings.
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('خدمة الموقع معطلة'),
            content:
                const Text('برجاء تفعيل خدمة تحديد الموقع من إعدادات الجهاز.'),
            actions: <Widget>[
              TextButton(
                child: const Text('إغلاق'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('فتح الإعدادات'),
                onPressed: () {
                  Geolocator
                      .openLocationSettings(); // Opens device location settings
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      }
      // Case 2: The app's permission to access location is denied.
      else if (error is PermissionDeniedException) {
        // Show a dialog that asks the user to grant permission from the app settings.
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('الإذن مرفوض'),
            content: const Text(
                'تم رفض إذن الوصول إلى الموقع. يرجى تفعيله من إعدادات التطبيق.'),
            actions: <Widget>[
              TextButton(
                child: const Text('إغلاق'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('فتح الإعدادات'),
                onPressed: () {
                  Geolocator.openAppSettings(); // Opens the app's settings
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      }
      // Case 3: Any other unexpected error.
      else {
        showDialog(
          context: context,
          builder: (builder) =>
              const AlertWidget(msg: 'حدث خطأ غير متوقع أثناء تحديد الموقع.'),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isLoading = false;
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.location_on),
      label: const Text('تحديد الموقع تلقائياً'),
      onPressed: () {
        if (UniversalPlatform.isLinux) {
          showDialog(
              context: context,
              builder: (builder) => const AlertWidget(
                  msg:
                      'خاصية التحديد التلقائي للإحداثيات غير مدعومة في لينكس'));
          return;
        }
        if (!_isLoading) {
          getLocation();
        }
      },
    );
  }
}

// Your AlertWidget for generic messages
class AlertWidget extends StatelessWidget {
  const AlertWidget({super.key, required this.msg});
  final String msg;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Text(msg, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}
