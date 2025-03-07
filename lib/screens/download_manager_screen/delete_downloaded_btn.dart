import 'package:flutter/material.dart';
import 'package:get/instance_manager.dart';
import 'package:yosria/screens/download_manager_screen/download_controller.dart';

class DeleteDownloadedBtn extends StatelessWidget {
  const DeleteDownloadedBtn(
      {super.key, required this.title, required this.directory});
  final String title, directory;

  @override
  Widget build(BuildContext context) {
    // TODO: pass dc down from upper widget?
    final dc = Get.put(DownloaderController());

    return IconButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                content: const Text(
                  'تأكيد حذف الملف',
                  textAlign: TextAlign.end,
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    // TODO: use AlertDialog theme?
                    style: const ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(Colors.red)),
                    onPressed: () {
                      dc.deleteFile(title: title, directory: directory);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'تأكيد',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            },
          );
        },
        icon: const Icon(Icons.delete_outline));
  }
}
