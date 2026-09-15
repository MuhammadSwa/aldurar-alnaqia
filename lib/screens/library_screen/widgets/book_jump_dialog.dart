import 'package:flutter/material.dart';

import 'package:aldurar_alnaqia/screens/library_screen/book_temp_loader.dart';

/// Shows the jump-to-page dialog and returns the parsed page, or null when
/// the dialog is dismissed. Range validation is the caller's responsibility.
Future<int?> showBookJumpDialog(
  BuildContext context, {
  required int currentPage,
  required int total,
}) {
  final textController =
      TextEditingController(text: currentPage.toString());
  // NOTE: showDialog pushes onto the ROOT navigator while this screen
  // lives on a shell-branch navigator, so the dialog is closed via
  // [dialogContext] and returns the parsed page (or null).
  Future<int?> show() => showDialog<int>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('الانتقال إلى صفحة', textAlign: TextAlign.center),
            content: TextField(
              controller: textController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'من 1 إلى $total',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.of(dialogContext)
                  .pop(BookTempLoader.parsePage(textController.text)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext)
                    .pop(BookTempLoader.parsePage(textController.text)),
                child: const Text('انتقال'),
              ),
            ],
          ),
        ),
      );

  return show().whenComplete(textController.dispose);
}
