// lib/screens/download_manager_screen/download_manager_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/screens/library_screen/library_screen.dart';
import 'download_controller.dart';

// NOTE: controllers the download manager screen not the downloads itself

class DownloadManagerController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  final DownloaderController _downloaderController =
      Get.find<DownloaderController>();
  final int initialIndex;

  DownloadManagerController({this.initialIndex = 0});

  // Data for the UI
  final RxMap<String, List<DownloadItem>> audioSections =
      <String, List<DownloadItem>>{}.obs;
  final RxList<DownloadItem> bookItems = <DownloadItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    tabController =
        TabController(length: 2, vsync: this, initialIndex: initialIndex);
    _loadAllItems();
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }

  void _loadAllItems() {
    // Load Audio Items
    final loadedAudio = <String, List<DownloadItem>>{};
    for (var entry in azkarWithNarrations.entries) {
      final items = entry.value
          .where((zikr) => zikr.url != null && zikr.url!.isNotEmpty)
          .map((zikr) => DownloadItem(
                id: zikr.title, // Use the title directly as the ID
                title: zikr.title,
                url: zikr.url!,
                type: DownloadType.narrations,
              ))
          .toList();
      if (items.isNotEmpty) {
        loadedAudio[entry.key] = items;
      }
    }
    audioSections.value = loadedAudio;

    // Load Book Items
    final loadedBooks = booksTitles.entries.map((entry) {
      return DownloadItem(
        id: entry.key, // Use the title directly as the ID
        title: entry.key,
        url: entry.value,
        type: DownloadType.books,
      );
    }).toList();
    bookItems.value = loadedBooks;
  }

  void cancelAllDownloads() {
    Get.dialog(
      AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: const Text('هل أنت متأكد من إلغاء جميع التحميلات الجارية؟'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              _downloaderController.cancelAllDownloads();
              Get.back();
              Get.snackbar(
                'تم الإلغاء',
                'تم إلغاء جميع التحميلات الجارية بنجاح.',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، إلغاء الكل'),
          ),
        ],
      ),
    );
  }

  Future<void> refreshPage() async {
    // Get all items that are displayed on the screen
    final allItems = [
      ...audioSections.values.expand((list) => list),
      ...bookItems
    ];

    // Create a list of futures to refresh the status of each file
    final refreshFutures = allItems.map(
        (item) => _downloaderController.refreshFileStatus(item.id, item.type));

    // Wait for all checks to complete
    await Future.wait(refreshFutures);

    Get.snackbar(
      'تم التحديث',
      'تم تحديث حالة جميع الملفات.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
