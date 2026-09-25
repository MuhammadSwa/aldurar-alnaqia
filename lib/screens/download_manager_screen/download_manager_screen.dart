import 'dart:async';

import 'package:aldurar_alnaqia/common/helpers/file_size.dart';
import 'package:aldurar_alnaqia/common/helpers/snackbar.dart';
import 'package:aldurar_alnaqia/common/widgets/app_tile.dart';
import 'package:aldurar_alnaqia/common/widgets/confirm_dialog.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_manager_controller.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_status_widgets.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class DownloadManagerTile extends ConsumerWidget {
  const DownloadManagerTile({
    required this.item,
    super.key,
  });

  final DownloadItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DownloadStatusBuilder(
      item: item,
      builder: (context, ref, downloader, isDownloading, isDownloaded) {
        // Size exists only for completed files; the stat is cheap and
        // re-runs only when the download status changes.
        final sizeFuture = isDownloaded
            ? ref.read(storageProvider).fileSizeBytes(item.type, item.id)
            : Future<int?>.value();
        return FutureBuilder<int?>(
          future: sizeFuture,
          builder: (context, snapshot) {
            // Size lives under the action button, never inside the
            // single-line ellipsized subtitle where long descriptions
            // would truncate it away.
            final sizeLabel =
                snapshot.data == null ? null : formatBytes(snapshot.data!);
            return AppTile(
              // Full name, title-only: it wraps to two lines.
              title: item.title,
              maxTitleLines: 2,
              leading: AppTileLeadingIcon(
                icon: item.type == DownloadType.books
                    ? Icons.menu_book_rounded
                    : Icons.audiotrack_rounded,
              ),
              trailing: SizedBox(
                width: 104,
                // Every state shares one footprint: a 48-high action row
                // end-aligned in the same slot. The circle sits exactly
                // where the download/delete icon sat; the X appears beside
                // it, so nothing already on screen ever moves.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Builder(
                      builder: (context) {
                        if (isDownloading) {
                          return _DownloadProgressIndicator(
                            id: item.id,
                            onCancel: () => downloader.cancelDownload(
                              item.id,
                              item.type,
                            ),
                          );
                        } else if (isDownloaded) {
                          return _DeleteButton(
                            onDelete: () =>
                                downloader.deleteFile(item.id, item.type),
                            title: item.title,
                          );
                        } else {
                          return _DownloadButton(
                            onDownload: () => downloader.startDownload(item),
                          );
                        }
                      },
                    ),
                    if (sizeLabel != null)
                      Text(
                        sizeLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: () async {
        final confirmed = await showConfirmDialog(
          context: context,
          title: 'تأكيد الحذف',
          content: 'هل أنت متأكد من حذف "$title"؟',
        );
        if (confirmed) onDelete();
      },
      icon: Icon(Icons.delete_outline, color: colorScheme.error),
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
            // X first, circle last: the circle lands on the exact pixels
            // the download/delete icon occupies in the other states.
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.cancel_outlined, size: 20),
              tooltip: 'إلغاء التحميل',
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(value: progress),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Rebuilds [builder] with the total bytes and count of downloaded [items],
/// plus how many items are currently downloading, refreshing on every
/// download-status change. State is kept across rebuilds so the last known
/// values stay visible while re-stat'ing.
class _DownloadedStats extends ConsumerStatefulWidget {
  const _DownloadedStats({required this.items, required this.builder});

  final List<DownloadItem> items;
  final Widget Function(
    BuildContext context,
    int bytes,
    int count,
    int activeCount,
  ) builder;

  @override
  ConsumerState<_DownloadedStats> createState() => _DownloadedStatsState();
}

class _DownloadedStatsState extends ConsumerState<_DownloadedStats> {
  int _bytes = 0;
  int _count = 0;
  int _active = 0;
  int _generation = 0;

  // Saved in initState: ref must never be touched in dispose.
  ValueNotifier<int>? _revision;

  @override
  void initState() {
    super.initState();
    _revision = ref.read(downloaderProvider).statusRevision;
    _revision!.addListener(_refresh);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _revision?.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    final downloader = ref.read(downloaderProvider);
    final storage = ref.read(storageProvider);
    var bytes = 0;
    var count = 0;
    var active = 0;
    for (final item in widget.items) {
      // Sync check on the live progress map; a revision bump mid-scan
      // restarts the scan, so staleness self-corrects.
      if (downloader.isDownloading(item.id)) active++;
      if (await downloader.ensureKnown(item.id, item.type)) {
        final size = await storage.fileSizeBytes(item.type, item.id);
        if (size != null) {
          bytes += size;
          count++;
        }
      }
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _bytes = bytes;
      _count = count;
      _active = active;
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _bytes, _count, _active);
}

class DownloadSection extends StatefulWidget {
  const DownloadSection({
    required this.title,
    required this.items,
    super.key,
  });

  final String title;
  final List<DownloadItem> items;

  @override
  State<DownloadSection> createState() => _DownloadSectionState();
}

class _DownloadSectionState extends State<DownloadSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DownloadedStats(
          items: widget.items,
          // activeCount is only meaningful to the app bar; unused here.
          builder: (context, bytes, count, activeCount) {
            final total = widget.items.length;
            final totalLabel = total == 1
                ? 'عنصر واحد'
                : total == 2
                    ? 'عنصران'
                    : '$total عناصر';
            String? downloadedLabel;
            if (count == 1) {
              downloadedLabel = 'عنصر واحد محمّل • ${formatBytes(bytes)}';
            } else if (count == 2) {
              downloadedLabel = 'عنصران محمّلان • ${formatBytes(bytes)}';
            } else if (count > 0) {
              downloadedLabel = '$count محمّلة • ${formatBytes(bytes)}';
            }
            final parts = [
              totalLabel,
              if (downloadedLabel != null) downloadedLabel,
            ];
            return AppTile(
              title: widget.title,
              subtitle: parts.join(' • '),
              leading: const AppTileLeadingIcon(
                icon: Icons.library_music_rounded,
              ),
              trailing: AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onTap: () => setState(() => _expanded = !_expanded),
            );
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  // Indent children to read as nested under the parent header.
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in widget.items)
                        DownloadManagerTile(item: item),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Arabic plural label for counts ('عنصر واحد' / 'عنصرين' / 'n عناصر').
String _itemsLabel(int n) {
  if (n == 1) return 'عنصر واحد';
  if (n == 2) return 'عنصرين';
  return '$n عناصر';
}

class DownloadManagerPage extends ConsumerStatefulWidget {
  const DownloadManagerPage({required this.initialIndex, super.key});

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

  late final Map<String, List<DownloadItem>> audioSections =
      DownloadManagerData.loadAudioSections();
  late final List<DownloadItem> bookItems = DownloadManagerData.loadBookItems();

  /// Every downloadable item across both tabs.
  late final List<DownloadItem> allItems = [
    ...bookItems,
    for (final items in audioSections.values) ...items,
  ];

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _clearAll(int count) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'حذف جميع التحميلات',
      content: 'سيتم حذف $count من العناصر المحمّلة نهائيًا. هل أنت متأكد؟',
      confirmLabel: 'حذف الكل',
      icon: Icons.delete_sweep_outlined,
    );
    if (!confirmed || !mounted) return;
    final downloader = ref.read(downloaderProvider);
    for (final item in allItems) {
      if (await downloader.ensureKnown(item.id, item.type)) {
        await downloader.deleteFile(item.id, item.type);
      }
    }
    if (mounted) showSnackBar(context, 'تم حذف جميع التحميلات');
  }

  /// Starts a batch download of everything not yet on the device.
  /// Confirms first — a full batch can be a lot of data.
  Future<void> _downloadAll() async {
    final downloader = ref.read(downloaderProvider);

    // Accurate count for the prompt (skips in-flight and downloaded).
    var pending = 0;
    for (final item in allItems) {
      if (downloader.isDownloading(item.id)) continue;
      if (await downloader.ensureKnown(item.id, item.type)) continue;
      pending++;
    }

    if (!mounted) return;
    if (pending == 0) {
      showSnackBar(context, 'جميع العناصر محمّلة أو قيد التحميل');
      return;
    }

    final confirmed = await showConfirmDialog(
      context: context,
      title: 'تحميل جميع الملفات',
      content: 'سيتم تحميل ${_itemsLabel(pending)} على الجهاز. هل أنت متأكد؟',
      confirmLabel: 'تحميل الكل',
      icon: Icons.download_for_offline_outlined,
    );
    if (!confirmed || !mounted) return;

    final started = await downloader.downloadAll(allItems);
    if (!mounted) return;
    // showSnackBar(
    //   context,
    //   started == 0
    //       ? 'التحميل قيد التنفيذ بالفعل'
    //       : 'بدأ تحميل ${_itemsLabel(started)}',
    // );
  }

  /// Stops every in-flight download. Files that already finished stay.
  /// No confirmation: canceling is non-destructive.
  Future<void> _cancelAllDownloads() async {
    final stopped = await ref.read(downloaderProvider).cancelAllDownloads();
    if (!mounted) return;
    showSnackBar(
      context,
      stopped == 0
          ? 'لا توجد تحميلات قيد التنفيذ'
          // : 'تم إيقاف تحميل ${_itemsLabel(stopped)}',
          : 'تم إيقاف التحميلات',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التحميلات'),
        actions: [
          _DownloadedStats(
            items: allItems,
            builder: (context, bytes, count, activeCount) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // One slot, two roles: while anything is downloading the
                // button is a stop button; otherwise it's download-all.
                if (activeCount > 0)
                  IconButton(
                    icon: const Icon(Icons.stop_circle_outlined),
                    tooltip: 'إيقاف جميع التحميلات',
                    onPressed: _cancelAllDownloads,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.download_for_offline_outlined),
                    tooltip: 'تحميل جميع الملفات',
                    // Disabled once everything is on the device.
                    onPressed:
                        count >= allItems.length ? null : () => _downloadAll(),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'حذف جميع التحميلات',
                  onPressed: count == 0 ? null : () => _clearAll(count),
                ),
              ],
            ),
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
            .map(
              (entry) => DownloadSection(
                title: entry.key,
                items: entry.value,
              ),
            )
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
          padding: EdgeInsets.all(16),
          child: Text('لا توجد كتب متاحة حاليًا.'),
        ),
      );
    }

    // Display a direct, non-expandable list for the books.
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
