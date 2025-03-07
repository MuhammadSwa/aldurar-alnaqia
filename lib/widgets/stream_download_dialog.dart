import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StreamOrDownloadDialog extends StatelessWidget {
  const StreamOrDownloadDialog(
      {super.key,
      required this.route,
      required this.toRun,
      required this.downloadRun});
  final String route;
  final Function toRun;
  final Function downloadRun;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.all(20),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push(route);
              downloadRun();
            },
            label: const Text('تحميل'),
            icon: const Icon(Icons.download),
          ),
          const SizedBox(width: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              toRun();
            },
            label: const Text('تشغيل بالإنترنت'),
            icon: const Icon(Icons.settings_input_antenna),
          )
        ],
      ),
    );
  }
}

// Widget streamOrDownloadDialog(
//     BuildContext context, String route, Function toRun) {
//   return AlertDialog(
//     contentPadding: const EdgeInsets.all(20),
//     content: Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         ElevatedButton.icon(
//           onPressed: () {
//             Navigator.pop(context);
//             context.push(route);
//           },
//           label: const Text('تحميل'),
//           icon: const Icon(Icons.download),
//         ),
//         const SizedBox(width: 20),
//         ElevatedButton.icon(
//           onPressed: () {
//             Navigator.pop(context);
//             toRun();
//           },
//           label: const Text('تشغيل بالإنترنت'),
//           icon: const Icon(Icons.settings_input_antenna),
//         )
//       ],
//     ),
//   );
// }
