import 'package:aldurar_alnaqia/MyDrawer.dart';
import 'package:aldurar_alnaqia/widgets/main_wrapper.dart';
import 'package:aldurar_alnaqia/widgets/stream_download_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'library_controller.dart';

// This map can stay here as it's static data
const booksTitles = <String, String>{
  'الدرر النقية في أوراد الطريقة اليسرية الصديقية الشاذلية':
      'https://archive.org/download/dorar_app_book/dorar_awrad.pdf',
  'الأنوار الجلية في الجمع بين دلائل الخيرات والصلوات اليسرية':
      'https://archive.org/download/dorar_app_book/anwar_galia.pdf',
  'الحضرة اليسرية الصديقية الشاذلية':
      'https://archive.org/download/dorar_app_book/dorar_alhadra.pdf',
  'إرشاد البرية إلى بعض معاني الحكم العطائية':
      "https://archive.org/download/dorar_app_book/irshad_albariyat_hukm_eatayiya.pdf",
  'الفتوحات اليسرية في شرح عقائد الأمة المحمدية':
      "https://archive.org/download/dorar_app_book/alfutuhat_alyasriat_eaqayid_alumat_almuhamadia.pdf",
  'شرح صلوات الأولياء':
      "https://archive.org/download/dorar_app_book/sharh_salawat_alawlia_ealaa_khatam_alanbia.pdf"
};

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controllers
    Get.put(DownloaderController());
    Get.put(GlobalDrawerController());
    final controller = Get.put(LibraryController());

    return Scaffold(
      key: controller.scaffoldKey,
      drawer: const MyDrawer(),
      appBar: AppBar(
        title: const Text('المكتبة'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: controller.openDrawer,
          tooltip: 'فتح القائمة',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: controller.refreshBookStatuses,
        child: Obx(
          () => ListView.builder(
            itemCount: controller.bookItems.length,
            itemBuilder: (context, index) {
              final bookItem = controller.bookItems[index];
              return _BookListTile(item: bookItem);
            },
          ),
        ),
      ),
    );
  }
}

class _BookListTile extends StatelessWidget {
  const _BookListTile({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final downloader = Get.find<DownloaderController>();
    // Trigger the check for file status. Obx will react to the result.
    downloader.isFileDownloaded(item.id, item.type);

    return Obx(() {
      final isDownloading = downloader.isDownloading(item.id);
      final isDownloaded = downloader.fileStatusCache[item.id] ?? false;

      return ListTile(
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        // === CHANGE IS HERE: Passing the cancel callback ===
        leading: _buildLeadingIcon(
          isDownloading: isDownloading,
          isDownloaded: isDownloaded,
          progressNotifier: downloader.downloadProgress[item.id],
          onCancel: () => downloader.cancelDownload(item.id),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _handleTap(context, isDownloaded, downloader),
      );
    });
  }

  // === CHANGE IS HERE: Added onCancel parameter and updated the Stack ===
  Widget _buildLeadingIcon({
    required bool isDownloading,
    required bool isDownloaded,
    required ValueNotifier<double>? progressNotifier,
    required VoidCallback onCancel,
  }) {
    if (isDownloading && progressNotifier != null) {
      // Use ValueListenableBuilder for efficient progress updates
      return ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (context, progress, child) {
          return SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: progress, strokeWidth: 2.5),
                // Replaced Text with IconButton for cancellation
                IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onCancel,
                  tooltip: 'إلغاء التحميل',
                ),
              ],
            ),
          );
        },
      );
    }

    return Icon(
      isDownloaded ? Icons.menu_book_sharp : Icons.cloud_outlined,
      // color:
      //     isDownloaded ? Get.theme.colorScheme.primary : Colors.grey.shade600,
      size: 30,
    );
  }

  void _handleTap(BuildContext context, bool isDownloaded,
      DownloaderController downloader) {
    if (isDownloaded) {
      // Use the item's title for navigation, which is the unique ID
      context.go('/library/pdfViewer/${item.title}');
    } else {
      _showDownloadOptionsDialog(context, downloader);
    }
  }

  void _showDownloadOptionsDialog(
      BuildContext context, DownloaderController downloader) {
    showDialog(
      context: context,
      builder: (dialogContext) => StreamOrDownloadDialog(
        item: item,
        onStream: () {
          Navigator.of(dialogContext).pop();
          context.go('/library/pdfViewer/${item.title}');
        },
        onDownload: () {
          Navigator.of(dialogContext).pop();
          downloader.startDownload(item);
        },
        onManageDownloads: () {
          Navigator.of(dialogContext).pop();
          context.push('/downloadManager/1');
        },
      ),
    );
  }
}
