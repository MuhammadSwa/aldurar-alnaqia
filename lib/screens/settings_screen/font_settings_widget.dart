import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/instance_manager.dart';
import 'package:yosria/services/shared_prefs.dart';

class FontController extends GetxController {
  var fontSize = SharedPreferencesService.getFontSize().obs;
  var fontFamily = SharedPreferencesService.getQuranFontFamily().obs;

  changeSize(double newSize) {
    fontSize.value = newSize;
    SharedPreferencesService.setFontSize(newSize);
  }

  changeFamily(String newFamily) {
    fontFamily.value = newFamily;
    SharedPreferencesService.setQuranFontFamily(newFamily);
  }
}

class FontFamilySettingsWidget extends StatefulWidget {
  const FontFamilySettingsWidget({super.key});

  @override
  State<FontFamilySettingsWidget> createState() =>
      _FontFamilySettingsWidgetState();
}

class _FontFamilySettingsWidgetState extends State<FontFamilySettingsWidget> {
  String araFontFamily() {
    final fc = Get.put(FontController());
    final eng = fc.fontFamily.value;
    return eng == 'Amiri' ? 'أميري' : 'قرآن أميري';
  }

  final fc = Get.put(FontController());
  @override
  Widget build(BuildContext context) {
    String fontFamily = araFontFamily();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text(
          'الخط القرآني',
          style: TextStyle(fontSize: 20),
        ),
        DropdownButton(
          // value: 0,
          hint: Text(fontFamily),
          onChanged: (font) {
            setState(() {
              fc.changeFamily(font!);
              fontFamily = araFontFamily();
            });
          },
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem(
              alignment: Alignment.centerRight,
              value: 'Amiri',
              child: Text('أميري'),
            ),
            DropdownMenuItem(
              alignment: Alignment.centerRight,
              value: 'AmiriQuran',
              child: Text('قرآن أميري'),
            ),
          ],
        ),
      ]),
    );
  }
}

class FontSizeSettingsWidget extends StatelessWidget {
  const FontSizeSettingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final fc = Get.put(FontController());

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'حجم الخط',
            // TODO: change using font theme
            style: TextStyle(fontSize: 20),
          ),
          IconButton(
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text(
                          'حجم الخط',
                          textAlign: TextAlign.center,
                        ),
                        content: SizedBox(
                          height: 80,
                          child: Obx(
                            () {
                              return Slider(
                                label: fc.fontSize.value.round().toString(),
                                divisions: 15,
                                min: 16,
                                max: 40,
                                value: fc.fontSize.value,
                                onChanged: fc.changeSize,
                              );
                            },
                          ),
                        ),
                      );
                    });
              },
              icon: const Icon(Icons.format_size))
        ],
      ),
    );
  }
}
