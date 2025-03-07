import 'package:flutter/material.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/instance_manager.dart';
import 'package:yosria/audioPlayer/audioPlayer.dart';
import 'package:yosria/common/helpers/helpers.dart';
import 'package:yosria/screens/download_manager_screen/download_controller.dart';
import 'package:yosria/widgets/stream_download_dialog.dart';

//
class PlayAudioBtnZikrPage extends StatelessWidget {
  const PlayAudioBtnZikrPage(
      {super.key, required this.title, required this.url});
  final String title;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final c = Get.put(Controller());

    return FutureBuilder(
      future: isFileDownloaded(title: title, directory: 'narrations'),
      builder: (context, snapshot) {
        // if file exists, just play the file
        return Obx(() {
          if (c.url.value != url && url != null) {
            if (snapshot.data == true) {
              return IconButton(
                onPressed: () {
                  c.initPlayer(url!, title, true);
                },
                icon: const Icon(Icons.volume_up),
              );
            } // if file doesn't exist, ask t he user to choose between streaming or downloading it
            else {
              return IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return StreamOrDownloadDialog(
                          route: '/downloadManager/0',
                          toRun: () {
                            c.initPlayer(url!, title, false);
                          },
                          downloadRun: () {
                            // start auto downloading the file
                            final dc = Get.put(DownloaderController());
                            dc.addTaskToQueue(
                                url: url!, id: title, directory: 'narrations');
                          },
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.volume_up));
            }
          } else {
            return Container();
          }
        });
      },
    );
  }
}
