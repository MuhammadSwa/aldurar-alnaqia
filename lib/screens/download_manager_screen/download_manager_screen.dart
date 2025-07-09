// lib/screens/download_manager_screen/download_manager_widgets.dart
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_manager_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'download_controller.dart';

class DownloadManagerTile extends StatelessWidget {
  const DownloadManagerTile({
    super.key,
    required this.item,
  });

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final DownloaderController controller = Get.find<DownloaderController>();
    // Trigger the file check. The result will be observed by the Obx widget.
    controller.isFileDownloaded(item.id, item.type);

    return ListTile(
      title: Text(
        item.title,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: SizedBox(
        width: 100,
        // Obx reactively builds the correct widget based on download state
        child: Obx(() {
          final isDownloading = controller.isDownloading(item.id);
          final isDownloaded = controller.fileStatusCache[item.id] ?? false;

          if (isDownloading) {
            return _DownloadProgressIndicator(
              id: item.id,
              onCancel: () => controller.cancelDownload(item.id),
            );
          } else if (isDownloaded) {
            return _DeleteButton(
              onDelete: () => controller.deleteFile(item.id, item.type),
              title: item.title,
            );
          } else {
            return _DownloadButton(
              onDownload: () => controller.startDownload(item),
            );
          }
        }),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.onDownload});
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onDownload,
      icon: const Icon(Icons.download_outlined),
      tooltip: 'تحميل',
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onDelete, required this.title});
  final VoidCallback onDelete;
  final String title;

  @override
  Widget build(BuildContext context) {
    // We use the 'context' provided by the build method.
    return IconButton(
      onPressed: () {
        // Replace Get.dialog with the standard Flutter showDialog function.
        // This is more robust as it uses the local BuildContext.
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل أنت متأكد من حذف "$title"؟'),
            actions: [
              TextButton(
                // Use the dialog's own context to pop itself.
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  onDelete();
                  // Close the dialog after performing the action.
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
      tooltip: 'حذف الملف',
    );
  }
}

class _DownloadProgressIndicator extends StatelessWidget {
  const _DownloadProgressIndicator({required this.id, this.onCancel});
  final String id;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final DownloaderController controller = Get.find<DownloaderController>();
    // Use ValueListenableBuilder for efficient progress updates
    return ValueListenableBuilder<double>(
      valueListenable: controller.downloadProgress[id]!,
      builder: (context, progress, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.cancel_outlined, size: 20),
              tooltip: 'إلغاء التحميل',
            ),
            const SizedBox(width: 8),
            Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: progress),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class DownloadSection extends StatelessWidget {
  const DownloadSection({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<DownloadItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Use a Card for better UI and visual separation of each section.
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // Ensures ripple effect is contained
      child: ExpansionTile(
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        // The children are the list of downloadable items.
        // They will only be built and shown when the tile is expanded.

        // Optional: Customize icon colors for a nicer look.
        iconColor: Theme.of(context).primaryColor,
        collapsedIconColor: Theme.of(context).textTheme.bodySmall?.color,
        children: items.map((item) => DownloadManagerTile(item: item)).toList(),
      ),
    );
  }
}

class DownloadManagerPage extends StatelessWidget {
  const DownloadManagerPage({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    // Put the core downloader and the page-specific controller
    Get.put(DownloaderController());
    final controller =
        Get.put(DownloadManagerController(initialIndex: initialIndex));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة التحميلات'),
          bottom: TabBar(
            controller: controller.tabController,
            tabs: const [
              Tab(icon: Icon(Icons.audiotrack), text: 'الصوتيات'),
              Tab(icon: Icon(Icons.book), text: 'الكتب'),
            ],
          ),
        ),
        body: TabBarView(
          controller: controller.tabController,
          children: const [
            _AudioTab(),
            _BooksTab(),
          ],
        ),
      ),
    );
  }
}

class _AudioTab extends GetView<DownloadManagerController> {
  const _AudioTab();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: controller.audioSections.entries
              .map((entry) => DownloadSection(
                    title: entry.key,
                    items: entry.value,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _BooksTab extends GetView<DownloadManagerController> {
  const _BooksTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.bookItems.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('لا توجد كتب متاحة حاليًا.'),
          ),
        );
      }

      // Display a direct, non-expandable list for the books.
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          // Static header for the books list
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'الكتب المتاحة',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // The list of book tiles
          ...controller.bookItems
              .map((item) => DownloadManagerTile(item: item)),
        ],
      );
    });
  }
}
