import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:aldurar_alnaqia/common/helpers/app_platform.dart';

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
        const PermissionDeniedException('Location permissions are denied'),
      );
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    // The UI will have to guide the user to the app settings.
    return Future.error(
      const PermissionDeniedException(
        'Location permissions are permanently denied, we cannot request permissions.',
      ),
    );
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition();
}

class LocationButtonWidget extends StatefulWidget {
  const LocationButtonWidget({
    super.key,
    required this.onGettingLocation,
    this.hasLocation = false,
  });
  final Function({required String latitude, required String longitude})
      onGettingLocation;
  final bool hasLocation;
  @override
  State<LocationButtonWidget> createState() => _LocationButtonWidgetState();
}

class _LocationButtonWidgetState extends State<LocationButtonWidget> {
  void _showSettingsDialog({
    required String title,
    required String message,
    required VoidCallback onOpenSettings,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final smallButtonStyle = TextButton.styleFrom(
          textStyle: theme.textTheme.bodySmall,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        );
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 64, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          actionsPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
          actionsAlignment: MainAxisAlignment.center,
          title: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          actions: <Widget>[
            TextButton(
              style: smallButtonStyle,
              child: const Text('إغلاق'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: smallButtonStyle,
              child: const Text('فتح الإعدادات'),
              onPressed: () {
                onOpenSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

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
        _showSettingsDialog(
          title: 'خدمة الموقع معطلة',
          message: 'برجاء تفعيل خدمة تحديد الموقع من إعدادات الجهاز.',
          onOpenSettings: Geolocator.openLocationSettings,
        );
      }
      // Case 2: The app's permission to access location is denied.
      else if (error is PermissionDeniedException) {
        // Show a dialog that asks the user to grant permission from the app settings.
        _showSettingsDialog(
          title: 'الإذن مرفوض',
          message:
              'تم رفض إذن الوصول إلى الموقع. يرجى تفعيله من إعدادات التطبيق.',
          onOpenSettings: Geolocator.openAppSettings,
        );
      }
      // Case 3: Any other unexpected error.
      else {
        if (!mounted) return;
        unawaited(
          showDialog(
            context: context,
            builder: (builder) =>
                const AlertWidget(msg: 'حدث خطأ غير متوقع أثناء تحديد الموقع.'),
          ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return ElevatedButton.icon(
      icon: _isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onPrimary,
              ),
            )
          : Icon(widget.hasLocation ? Icons.check_circle : Icons.location_on),
      label: Text(
        widget.hasLocation ? 'تم تحديد الموقع' : 'تحديد الموقع تلقائياً',
      ),
      onPressed: () {
        if (AppPlatform.isLinux) {
          showDialog(
            context: context,
            builder: (builder) => const AlertWidget(
              msg: 'خاصية التحديد التلقائي للإحداثيات غير مدعومة في لينكس',
            ),
          );
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
