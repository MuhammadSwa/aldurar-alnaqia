import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yosria/services/location_service.dart';
import 'package:universal_platform/universal_platform.dart';

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
    await determinePosition().then((value) {
      widget.onGettingLocation(
        latitude: value.latitude.toString(),
        longitude: value.longitude.toString(),
      );
    }).catchError((error) {
      showDialog(
        // TODO: fix this use get dialog?
        context: context,
        builder: (builder) =>
            const AlertWidget(msg: 'برجاء تشغيل خدمة تحديد الموقع'),
      );
    });
    // final position = await determinePosition();
    // widget.onGettingLocation(
    //   latitude: position.latitude.toString(),
    //   longitude: position.longitude.toString(),
    // );
    setState(() {
      _isLoading = false;
    });
  }

  bool _isLoading = false;
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: _isLoading
          ? const CircularProgressIndicator()
          : const Icon(Icons.location_on),
      label: const Text(
        'تحديد تلقائي',
        // TODO: use theme for ElevatedButton Text.
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      onPressed: () {
        if (UniversalPlatform.isLinux) {
          showDialog(
              context: context,
              builder: (builder) => const AlertWidget(
                  msg:
                      'خاصية التحديد التلقائي للإحداثيات غير مدعومة في لينكس'));
          return;
        }
        _isLoading ? null : getLocation();
      },
    );
  }
}

class AlertWidget extends StatelessWidget {
  const AlertWidget({super.key, required this.msg});
  final String msg;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: AlertDialog(
            content: Text(msg, textAlign: TextAlign.center),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        ));
  }
}
