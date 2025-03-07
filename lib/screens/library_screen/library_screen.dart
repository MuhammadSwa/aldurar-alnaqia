import 'package:flutter/material.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/instance_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:yosria/common/helpers/helpers.dart';
import 'package:yosria/screens/download_manager_screen/download_controller.dart';
import 'package:yosria/widgets/stream_download_dialog.dart';

const booksTitles = <String, String>{
  'الدرر النقية في أوراد الطريقة اليسرية الصديقية الشاذلية':
      'https://archive.org/download/dorar_app_book/dorar_awrad.pdf',
  'الأنوار الجلية في الجمع بين دلائل الخيرات والصلوات اليسرية':
      'https://archive.org/download/dorar_app_book/anwar_galia.pdf',
  'الحضرة اليسرية الصديقية الشاذلية':
      'https://archive.org/download/dorar_app_book/dorar_alhadra.pdf',
};

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('المكتبة'),
        ),
        body: ListView(
          children: [
            for (String title in booksTitles.keys) ...{
              BookListTile(title: title, url: booksTitles[title]!)
            }
          ],
        ));
  }
}

class BookListTile extends StatelessWidget {
  const BookListTile({super.key, required this.title, required this.url});
  final String title, url;

  @override
  Widget build(BuildContext context) {
    final dc = Get.put(DownloaderController());
    return Obx(() {
      // NOTE : don't delete this.
      final fileDownloaded = dc.filesDownloaded[title];
      return FutureBuilder(
          future: isFileDownloaded(title: title, directory: 'books'),
          builder: (context, snapshot) {
            if (snapshot.data == true) {
              return ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                leading: const Icon(Icons.menu_book_sharp),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.go('/library/pdfViewer/$title');
                },
              );
            } else {
              // show dialog if stream go stream, if download go download
              return ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.chevron_right),

                // TODO: iconButton based on ifFileDownlaoded().
                leading: const Icon(
                  Icons.download_for_offline,
                  // color: Colors.lightGreenAccent,
                ),
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return StreamOrDownloadDialog(
                          route: '/downloadManager/1',
                          toRun: () {
                            context.go('/library/pdfViewer/$title');
                          },
                          downloadRun: () {
                            // start auto downloading the file
                            final dc = Get.put(DownloaderController());
                            dc.addTaskToQueue(
                                url: url, id: title, directory: 'books');
                          },
                        );
                      });
                  // context.push('/downloadManager/1');
                },
              );
            }
          });
    });
  }
}
