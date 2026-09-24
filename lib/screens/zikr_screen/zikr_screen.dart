import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/play_audio_btn_zikr_page.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/widgets/bayt_widget.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/widgets/swipe_hint_dialog.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/widgets/zikr_inline_text.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/zikr_blocks.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/helia_nasab_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class SlidableZikrScreen extends StatefulWidget {

  const SlidableZikrScreen({
    required this.zikrIds, required this.initialIndex, super.key,
  });
  final List<String> zikrIds;
  final int initialIndex;

  @override
  State<SlidableZikrScreen> createState() => _SlidableZikrScreenState();
}

class _SlidableZikrScreenState extends State<SlidableZikrScreen> {
  late PageController _pageController;
  late String _currentId;
  late Zikr _currentZikr;

  @override
  void initState() {
    super.initState();
    final safeIndex = widget.initialIndex.clamp(0, widget.zikrIds.length - 1);
    _pageController = PageController(initialPage: safeIndex);
    _updateCurrentZikr(safeIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSwipeHint());
  }

  /// Shows the hand-slide onboarding once, the first time the user opens a
  /// collection with more than one zikr to swipe through.
  Future<void> _maybeShowSwipeHint() async {
    if (!mounted || widget.zikrIds.length < 2) return;
    if (!SharedPreferencesService.isInitialized) return;
    if (SharedPreferencesService.getSwipeHintSeen()) return;
    await SharedPreferencesService.setSwipeHintSeen(true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SwipeHintDialog(
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _updateCurrentZikr(int index) {
    _currentId = widget.zikrIds[index];
    _currentZikr = resolveZikr(_currentId) ?? zikrById.values.first;
  }

  /// Playlist for continuous playback: every list item that has audio, in
  /// slide order. The controller plays local files first and streams the
  /// rest automatically.
  List<AudioTrack> _audioQueue() {
    return [
      for (final id in widget.zikrIds)
        if (resolveZikr(id) case final Zikr z when z.hasAudio)
          AudioTrack(id: z.id, title: z.title, remoteUrl: z.url!),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ZikrReaderScaffold(
      title: _currentZikr.title,
      actions: [
        // The action button updates reactively based on the current Zikr.
        // The full slide order is passed as a queue so the mini player
        // can auto-advance through it.
        PlayAudioBtnZikrPage(
          id: _currentZikr.id,
          title: _currentZikr.title,
          url: _currentZikr.url,
          queue: _audioQueue(),
        ),
      ],
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.zikrIds.length,
        // This callback updates the AppBar title when you swipe to a new page
        onPageChanged: (index) {
          setState(() {
            _updateCurrentZikr(index);
          });
        },
        // The builder creates the content widget for each Zikr.
        // Special compositions reuse their shared content widgets (no nested
        // Scaffold) so every page — including the initial one — stays
        // swipeable inside this outer PageView.
        itemBuilder: (context, index) {
          final zikr = resolveZikr(widget.zikrIds[index]);
          switch (zikr?.kind) {
            case ZikrKind.hilyaNasab:
              return const HeliaNasabContent();
            case ZikrKind.tareeqaSanad:
              return const TareeqaSanadContent();
            case ZikrKind.text:
            case null:
              return ZikrContentWidget(zikrId: widget.zikrIds[index]);
          }
        },
      ),
    );
  }
}

/// Reader chrome shared by standalone and swipeable azkar.
///
/// The bar gets out of the way as soon as vertical reading starts. Tapping
/// the page toggles it, and returning the scroll position to the top shows it.
class ZikrReaderScaffold extends StatefulWidget {
  const ZikrReaderScaffold({
    required this.title,
    required this.actions,
    required this.child,
  });

  final String title;
  final List<Widget> actions;
  final Widget child;

  @override
  State<ZikrReaderScaffold> createState() => _ZikrReaderScaffoldState();
}

/// Intent emitted by embedded reader content, such as a PDF view.
enum ZikrReaderChromeAction { toggle, hide }

/// Lets embedded reader content control the containing reader's AppBar.
class ZikrReaderChromeNotification extends Notification {
  const ZikrReaderChromeNotification(this.action);

  final ZikrReaderChromeAction action;
}

class _ZikrReaderScaffoldState extends State<ZikrReaderScaffold> {
  bool _appBarVisible = true;

  void _showAppBar() {
    if (!_appBarVisible && mounted) setState(() => _appBarVisible = true);
  }

  void _hideAppBar() {
    if (_appBarVisible && mounted) setState(() => _appBarVisible = false);
  }

  void _toggleAppBar() {
    if (!mounted) return;
    setState(() => _appBarVisible = !_appBarVisible);
  }

  bool _handleChromeIntent(ZikrReaderChromeNotification notification) {
    switch (notification.action) {
      case ZikrReaderChromeAction.toggle:
        _toggleAppBar();
        return true;
      case ZikrReaderChromeAction.hide:
        _hideAppBar();
        return true;
    }
  }

  bool _handleScroll(ScrollNotification notification) {
    // The outer PageView also emits scroll notifications. Only the vertical
    // reader scroll should affect the reader chrome.
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification.metrics.pixels <= notification.metrics.minScrollExtent) {
      _showAppBar();
    } else if (notification is ScrollUpdateNotification &&
        notification.scrollDelta != 0) {
      _hideAppBar();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ZikrReaderChromeNotification>(
      onNotification: _handleChromeIntent,
      child: Scaffold(
        appBar: _appBarVisible
            ? AppBar(title: Text(widget.title), actions: widget.actions)
            : null,
        body: NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleAppBar,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class ZikrScreen extends StatelessWidget {
  const ZikrScreen({
    required this.zikrId, super.key,
    this.zikrIds,
    this.index,
  });

  final String zikrId;
  final int? index;
  final List<String>? zikrIds;

  @override
  Widget build(BuildContext context) {
    if (zikrIds != null &&
        index != null &&
        index! >= 0 &&
        index! < zikrIds!.length) {
      return SlidableZikrScreen(zikrIds: zikrIds!, initialIndex: index!);
    }
    // Find the specific Zikr data using the id; show a friendly page
    // instead of crashing when the id is unknown (e.g. from search).
    final zikr = resolveZikr(zikrId);

    if (zikr == null) {
      return Scaffold(
        appBar: AppBar(title: Text(zikrId)),
        body: const Center(
          child: Text(
            'لم يتم العثور على هذا الذكر',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return ZikrReaderScaffold(
      title: zikr.title,
      actions: [
        PlayAudioBtnZikrPage(
          id: zikr.id,
          title: zikr.title,
          url: zikr.url,
        ),
      ],
      child: ZikrContentWidget(
        zikrId: zikr.id,
      ),
    );
  }
}

class ZikrContentWidget extends ConsumerWidget {
  const ZikrContentWidget({required this.zikrId, super.key});
  final String zikrId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zikr = resolveZikr(zikrId);
    if (zikr == null) {
      return const Center(child: Text('لم يتم العثور على هذا الذكر'));
    }
    // Single subscription for the whole page. Previously every paragraph
    // subscribed via ZikrInlineText, multiplying rebuild work.
    final fontSize = ref.watch(fontSizeProvider);
    // Parsed once per zikr id; long contents (dalayil/yousria) no longer
    // re-split on every font-size/theme rebuild.
    final blocks = blocksForZikr(id: zikr.id, content: zikr.content);
    final hasNotes = zikr.notes != '';
    final hasFooter = zikr.footer != '';
    final itemCount = blocks.length + (hasNotes ? 1 : 0) + (hasFooter ? 1 : 0);

    // Lazily built: only visible paragraphs run regex styling + layout.
    // Previously SingleChildScrollView + Column built all N blocks upfront.
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (hasNotes && index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZikrInlineText(
                text: zikr.notes,
                fontSize: fontSize,
                textAlign: TextAlign.start,
                sizeFactor: .7,
              ),
              const Divider(),
            ],
          );
        }
        final blockIndex = index - (hasNotes ? 1 : 0);
        if (blockIndex < blocks.length) {
          final topGap = blockIndex > 0
              ? _gapBefore(blocks[blockIndex - 1], blocks[blockIndex], fontSize)
              : 0.0;
          return Padding(
            padding: EdgeInsets.only(top: topGap),
            child: _blockWidget(blocks[blockIndex], fontSize),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            ZikrInlineText(
              text: zikr.footer,
              fontSize: fontSize,
              textAlign: TextAlign.start,
              sizeFactor: .7,
            ),
          ],
        );
      },
    );
  }

  /// Tighter rhythm inside a qasida; airier spacing around prose/headings.
  double _gapBefore(ZikrBlock previous, ZikrBlock current, double fontSize) {
    if (previous is BaytBlock && current is BaytBlock) {
      return fontSize * .45;
    }
    return fontSize * .7;
  }

  Widget _blockWidget(ZikrBlock block, double fontSize) {
    return switch (block) {
      ProseBlock(:final text) => ZikrInlineText(text: text, fontSize: fontSize),
      HeadingBlock(:final text) => ZikrInlineText(
          text: text,
          fontSize: fontSize,
          textAlign: TextAlign.center,
          sizeFactor: 1.15,
          bold: true,
        ),
      BaytBlock(:final sadr, :final ajz) =>
        BaytWidget(sadr: sadr, ajz: ajz, fontSize: fontSize),
    };
  }
}
