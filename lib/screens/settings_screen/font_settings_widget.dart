import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

class FontSizeSettingsWidget extends ConsumerWidget {
  const FontSizeSettingsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'حجم الخط',
            style: TextStyle(fontSize: 20),
          ),
          IconButton(
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (dialogContext) {
                      return AlertDialog(
                        title: const Text(
                          'حجم الخط',
                          textAlign: TextAlign.center,
                        ),
                        content: SizedBox(
                          height: 80,
                          child: Consumer(
                            builder: (context, ref, _) {
                              final size = ref.watch(fontSizeProvider);
                              return Slider(
                                label: size.round().toString(),
                                divisions: 15,
                                min: 16,
                                max: 40,
                                value: size,
                                onChanged: ref
                                    .read(fontSizeProvider.notifier)
                                    .change,
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
