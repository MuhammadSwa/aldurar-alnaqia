import 'package:aldurar_alnaqia/screens/library_screen/book_temp_loader.dart';
import 'package:material_ui/material_ui.dart';

/// Shows the jump-to-page dialog and returns the parsed page, or null when
/// the dialog is dismissed. Range validation is the caller's responsibility.
Future<int?> showBookJumpDialog(
  BuildContext context, {
  required int currentPage,
  required int total,
}) {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => _BookJumpDialog(
      currentPage: currentPage,
      total: total,
    ),
  );
}

class _BookJumpDialog extends StatefulWidget {
  const _BookJumpDialog({required this.currentPage, required this.total});

  final int currentPage;
  final int total;

  @override
  State<_BookJumpDialog> createState() => _BookJumpDialogState();
}

class _BookJumpDialogState extends State<_BookJumpDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController =
        TextEditingController(text: widget.currentPage.toString());
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit(BuildContext dialogContext) {
    // Release focus (and the keyboard) before popping. Popping while the
    // TextField still holds primary focus leaves FocusScope/MediaQuery
    // dependents attached during route deactivation, tripping the
    // '_dependents.isEmpty' assert in debug builds.
    FocusScope.of(dialogContext).unfocus();
    Navigator.of(dialogContext)
        .pop(BookTempLoader.parsePage(_textController.text));
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: dialogContext (from showDialog's builder) must be used for
    // pop/unfocus — the outer screen context belongs to a different
    // navigator (shell branch vs root).
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('الانتقال إلى صفحة', textAlign: TextAlign.center),
        content: TextField(
          controller: _textController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'من 1 إلى ${widget.total}',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _submit(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop();
            },
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => _submit(context),
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
  }
}
