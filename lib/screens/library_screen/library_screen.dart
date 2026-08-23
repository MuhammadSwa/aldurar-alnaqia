import 'package:aldurar_alnaqia/my_drawer.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/widgets/stream_download_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/router/nav_helpers.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';

// This map can stay here as it's static data
const booksTitles = <String, String>{
  'الدرر النقية في أوراد الطريقة اليسرية الصديقية الشاذلية':
      'https://archive.org/download/dorar_app_book/dorar_awrad.pdf',
  'الأنوار الجلية في الجمع بين دلائل الخيرات والصلوات اليسرية':
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

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<DownloadItem> bookItems = booksTitles.entries.map((entry) {
    return DownloadItem(
      // Use the book title as the unique and consistent ID
      id: entry.key,
      title: entry.key,
      url: entry.value,
      type: DownloadType.books,
    );
  }).toList();

  Future<void> _refreshBookStatuses() async {
    final downloader = ref.read(downloaderProvider);
    await Future.wait(
      bookItems.map((item) => downloader.refreshFileStatus(item.id, item.type)),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تحديث حالة الكتب.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(drawerRegistryProvider).registerScaffoldKey(_scaffoldKey);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const MyDrawer(),
      appBar: AppBar(
        title: const Text('المكتبة'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'فتح القائمة',
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث الحالة',
            onPressed: _refreshBookStatuses,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: bookItems.length,
        itemBuilder: (context, index) {
          final bookItem = bookItems[index];
          return _BookListTile(item: bookItem);
        },
      ),
    );
  }
}

class _BookListTile extends ConsumerWidget {
  const _BookListTile({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloader = ref.watch(downloaderProvider);
    // Trigger a coalesced status check outside reactive build updates
    downloader.ensureKnown(item.id, item.type);

    return ValueListenableBuilder<int>(
      valueListenable: downloader.statusRevision,
      builder: (context, _, __) {
        final isDownloading = downloader.isDownloading(item.id);
        final isDownloaded = downloader.cachedStatus(item.id) ?? false;

        return ListTile(
          title: Text(item.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          leading: _buildLeadingIcon(
            context: context,
            isDownloading: isDownloading,
            isDownloaded: isDownloaded,
            progressNotifier: downloader.progressNotifierFor(item.id),
            onCancel: () => downloader.cancelDownload(item.id),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _handleTap(context, ref, isDownloaded),
        );
      },
    );
  }

  Widget _buildLeadingIcon({
    required BuildContext context,
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
      size: 30,
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref, bool isDownloaded) {
    if (isDownloaded) {
      // Open viewer; it will auto-restore last page.
      AppNav.goToPdfViewer(context, item.title);
    } else {
      _showDownloadOptionsDialog(context, ref);
    }
  }

  void _showDownloadOptionsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => StreamOrDownloadDialog(
        item: item,
        onStream: () {
          Navigator.of(dialogContext).pop();
          AppNav.goToPdfViewer(context, item.title);
        },
        onDownload: () {
          Navigator.of(dialogContext).pop();
          ref.read(downloaderProvider).startDownload(item);
        },
        onManageDownloads: () {
          Navigator.of(dialogContext).pop();
          AppNav.goToDownloadManager(context, 1);
        },
      ),
    );
  }
}
