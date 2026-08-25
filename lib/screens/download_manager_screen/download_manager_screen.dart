// lib/screens/download_manager_screen/download_manager_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'download_controller.dart';
import 'download_manager_controller.dart';

class DownloadManagerTile extends ConsumerWidget {
  const DownloadManagerTile({
    super.key,
    required this.item,
  });

  final DownloadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloader = ref.watch(downloaderProvider);
    // Trigger a coalesced status check without side effects in build
    downloader.ensureKnown(item.id, item.type);

    return ListTile(
      title: Text(
        item.title,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: SizedBox(
        width: 100,
        // Rebuild on any file-status change
        child: ValueListenableBuilder<int>(
          valueListenable: downloader.statusRevision,
          builder: (context, _, __) {
            final isDownloading = downloader.isDownloading(item.id);
            final isDownloaded =
                downloader.cachedStatus(item.id, item.type) ?? false;

            if (isDownloading) {
              return _DownloadProgressIndicator(
                id: item.id,
                onCancel: () => downloader.cancelDownload(item.id, item.type),
              );
            } else if (isDownloaded) {
              return _DeleteButton(
                onDelete: () => downloader.deleteFile(item.id, item.type),
                title: item.title,
              );
            } else {
              return _DownloadButton(
                onDownload: () => downloader.startDownload(item),
              );
            }
          },
        ),
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
    return IconButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text('هل أنت متأكد من حذف "$title"؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  onDelete();
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

class _DownloadProgressIndicator extends ConsumerWidget {
  const _DownloadProgressIndicator({required this.id, this.onCancel});
  final String id;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(downloaderProvider).progressNotifierFor(id);
    if (notifier == null) {
      return const SizedBox.shrink();
    }

    // Use ValueListenableBuilder for efficient progress updates
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
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
        iconColor: Theme.of(context).primaryColor,
        collapsedIconColor: Theme.of(context).textTheme.bodySmall?.color,
        children: items.map((item) => DownloadManagerTile(item: item)).toList(),
      ),
    );
  }
}

class DownloadManagerPage extends ConsumerStatefulWidget {
  const DownloadManagerPage({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  ConsumerState<DownloadManagerPage> createState() =>
      _DownloadManagerPageState();
}

class _DownloadManagerPageState extends ConsumerState<DownloadManagerPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialIndex,
  );

  late final audioSections = DownloadManagerData.loadAudioSections();
  late final bookItems = DownloadManagerData.loadBookItems();

  Future<void> _cancelAllDownloads() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content:
            const Text('هل أنت متأكد من إلغاء جميع التحميلات الجارية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، إلغاء الكل'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ref.read(downloaderProvider).cancelAllDownloads();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إلغاء جميع التحميلات الجارية بنجاح.'),
      ),
    );
  }

  Future<void> _refreshPage() async {
    final downloader = ref.read(downloaderProvider);
    final allItems = [
      ...audioSections.values.expand((list) => list),
      ...bookItems
    ];

    await Future.wait(
      allItems.map((item) => downloader.refreshFileStatus(item.id, item.type)),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث حالة جميع الملفات.')),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة التحميلات'),
          actions: [
            IconButton(
              tooltip: 'إلغاء كل التحميلات',
              onPressed: _cancelAllDownloads,
              icon: const Icon(Icons.cancel_schedule_send),
            ),
            IconButton(
              tooltip: 'تحديث الحالة',
              onPressed: _refreshPage,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.audiotrack), text: 'الصوتيات'),
              Tab(icon: Icon(Icons.book), text: 'الكتب'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _AudioTab(audioSections: audioSections),
            _BooksTab(bookItems: bookItems),
          ],
        ),
      ),
    );
  }
}

class _AudioTab extends StatelessWidget {
  const _AudioTab({required this.audioSections});

  final Map<String, List<DownloadItem>> audioSections;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: audioSections.entries
            .map((entry) => DownloadSection(
                  title: entry.key,
                  items: entry.value,
                ))
            .toList(),
      ),
    );
  }
}

class _BooksTab extends StatelessWidget {
  const _BooksTab({required this.bookItems});

  final List<DownloadItem> bookItems;

  @override
  Widget build(BuildContext context) {
    if (bookItems.isEmpty) {
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
        ...bookItems.map((item) => DownloadManagerTile(item: item)),
      ],
    );
  }
}
