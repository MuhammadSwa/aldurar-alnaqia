import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/setting_popup_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drawer setting that controls what happens when the user opens a file
/// (audio or book) that is not downloaded yet.
///
/// Single preference shared by both flows; the "تذكر الاختيار" checkbox in
/// [StreamOrDownloadDialog] writes to the same provider.
class FileActionSettingWidget extends ConsumerWidget {
  const FileActionSettingWidget({super.key});

  static String label(FileOpenAction action) {
    return switch (action) {
      FileOpenAction.ask => 'عرض الخيارات كل مرة',
      FileOpenAction.open => 'فتح مباشر دائمًا',
      FileOpenAction.download => 'تحميل دائمًا',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(fileOpenActionProvider);
    return SettingPopupTile<FileOpenAction>(
      title: 'اختيارات التحميل',
      value: current,
      values: FileOpenAction.values,
      labelFor: label,
      onSelected: (value) =>
          ref.read(fileOpenActionProvider.notifier).set(value),
    );
  }
}
