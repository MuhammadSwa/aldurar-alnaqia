import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yosria/screens/settings_screen/font_settings_widget.dart';
import 'package:yosria/screens/settings_screen/toggleThemeBtn_widget.dart';
import 'package:yosria/screens/settings_screen/yousriaBeginningDayDropdown_widget.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: make widget for each settings category?
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإعدادات'),
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المظهر',
                    // TODO: change using font theme
                    style: TextStyle(fontSize: 20),
                  ),
                  ToggleThemeBtn()
                ],
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'بداية الصلوات اليسرية',
                    // TODO: change using font theme
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                  YousriaBeginningDayDropDown()
                ],
              ),
            ),
            const Divider(),
            const FontSizeSettingsWidget(),
            const FontFamilySettingsWidget(),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'إدارة التحميلات',
                    // TODO: change using font theme
                    style: TextStyle(fontSize: 20),
                  ),
                  IconButton(
                      onPressed: () {
                        context.push('/downloadManager/0');
                      },
                      icon: const Icon(Icons.cloud_download_outlined))
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
//


