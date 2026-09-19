import 'package:material_ui/material_ui.dart';

/// Single app-wide snackbar helper. Hides the current one first so messages
/// never queue
void showSnackBar(
  BuildContext context,
  String msg, {
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        content: Text(msg),
      ),
    );
}
