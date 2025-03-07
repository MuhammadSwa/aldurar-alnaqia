import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:get/instance_manager.dart';
import 'package:yosria/screens/download_manager_screen/download_controller.dart';

class DownloadManagerProgressWidget extends StatelessWidget {
  const DownloadManagerProgressWidget({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final dc = Get.put(DownloaderController());
    // TODO: show i pass it down?
    final queue = dc.queues[title];
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        IconButton(
            onPressed: () {
              // NOTE: im removing it here so widget instantly changes,instead removing it in the listener
              // dc.queues.remove(title);
              FileDownloader().cancelTaskWithId(title);
            },
            icon: const Icon(Icons.close)),
        Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: queue!.value,
              color: Colors.blue,
            ),
            Text(
              '${(queue.value * 100).round().toString()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        )
      ],
    );
  }
}
