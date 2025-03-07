import 'package:flutter/material.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/instance_manager.dart';
import 'package:yosria/screens/download_manager_screen/delete_downloaded_btn.dart';
import 'package:yosria/screens/download_manager_screen/download_controller.dart';
import 'package:yosria/screens/download_manager_screen/download_manager_progress_widget.dart';

class DownloaderProgressBtn extends StatelessWidget {
  const DownloaderProgressBtn(
      {super.key,
      required this.title,
      required this.downloadUrl,
      required this.directory});

  final String title, downloadUrl, directory;

  @override
  Widget build(BuildContext context) {
    final dc = Get.put(DownloaderController());
    return Obx(() {
      final queue = dc.queues[title];
      // don't delete this.
      final fileDownloaded = dc.filesDownloaded[title];
      return FutureBuilder(
          // TODO: make downloadable list
          // TODO: how to get rid of calling this everytime,
          // instead we should check a place that has all downloaded files.

          future: dc.isFileDownloaded(title: title, directory: directory),
          builder: (context, snapshot) {
            if (queue != null) {
              return DownloadManagerProgressWidget(title: title);
            }
            // show DeleteDownloadedBtn if file exists
            else if (snapshot.data == true) {
              return DeleteDownloadedBtn(title: title, directory: directory);
            }
            // if file doesn't exists, and it's not downloading, show download btn
            else {
              return IconButton(
                onPressed: () {
                  dc.addTaskToQueue(
                      url: downloadUrl, id: title, directory: directory);
                },
                icon: const Icon(Icons.download),
              );
            }
          });
    });
  }
}
