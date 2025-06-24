import 'package:aldurar_alnaqia/widgets/main_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/screens/library_screen/library_screen.dart'; // For booksTitles

class LibraryController extends GetxController {
  final DownloaderController _downloader = Get.find<DownloaderController>();
  final GlobalDrawerController _drawerController =
      Get.find<GlobalDrawerController>();
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  // Use an observable list to hold the book data
  final RxList<DownloadItem> bookItems = <DownloadItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    _drawerController.registerScaffoldKey(scaffoldKey);
    _loadBooks();
  }

  void openDrawer() {
    scaffoldKey.currentState?.openDrawer();
  }

  void _loadBooks() {
    final items = booksTitles.entries.map((entry) {
      return DownloadItem(
        // Use the book title as the unique and consistent ID
        id: entry.key,
        title: entry.key,
        url: entry.value,
        type: DownloadType.books,
      );
    }).toList();
    bookItems.assignAll(items);
  }

  // Correctly implemented refresh logic
  Future<void> refreshBookStatuses() async {
    final refreshFutures = bookItems.map(
      (item) => _downloader.refreshFileStatus(item.id, item.type),
    );
    // Wait for all file status checks to complete
    await Future.wait(refreshFutures);

    Get.snackbar(
      'اكتمل التحديث',
      'تم تحديث حالة الكتب.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    );
  }
}
