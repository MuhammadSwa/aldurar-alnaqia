import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/common/reader/pdf_reader_content.dart';
import 'package:aldurar_alnaqia/common/reader/reader_page.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/router/swipe_back.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/widgets/bayt_widget.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/widgets/swipe_hint_dialog.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/widgets/zikr_inline_text.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/zikr_blocks.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/helia_nasab_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Swipeable azkar reader: one [SwipeBackPageView] over a collection of zikr
/// ids. Swipe → for the next zikr, ← for the previous one, and ← on the
/// first goes back to the list.
///
/// Special compositions (Hilya/Nasab manuscript, Tareeqa/Sanad) reuse their
/// shared content widgets with no nested [Scaffold], so every page —
/// including the initial one — stays swipeable. Chrome (title + audio
/// action) comes from the shared [ZikrReaderPage] and tracks the visible
/// zikr because this State rebuilds on every page change.
class SlidableZikrScreen extends StatefulWidget {
  const SlidableZikrScreen({
    required this.zikrIds, required this.initialIndex, super.key,
  }) : _fromList = true;

  /// One zikr opened on its own (search, home tiles, deep links): no
  /// neighbours and no playlist, but ← still goes back.
  SlidableZikrScreen.single(String zikrId, {super.key})
      : zikrIds = [zikrId],
        initialIndex = 0,
        _fromList = false;

  final List<String> zikrIds;
  final int initialIndex;
  final bool _fromList;

  @override
  State<SlidableZikrScreen> createState() => _SlidableZikrScreenState();
}

class _SlidableZikrScreenState extends State<SlidableZikrScreen> {
  late PageController _pageController;
  late String _currentId;
  late Zikr _currentZikr;

  /// Manuscript pages currently zoomed in; while any is, horizontal drags
  /// pan it instead of paging or swiping back.
  final Set<Object> _zoomedManuscripts = {};

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

  void _handleZoomChanged(Object manuscript, {required bool zoomed}) {
    final changed = zoomed
        ? _zoomedManuscripts.add(manuscript)
        : _zoomedManuscripts.remove(manuscript);
    if (!changed) return;
    // Reports arrive mid-build and from disposing pages: rebuild after.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) setState(() {});
      })
      ..ensureVisualUpdate();
  }

  /// Playlist for continuous playback: every list item that has audio, in
  /// slide order. The controller plays local files first and streams the
  /// rest automatically. A zikr opened on its own plays alone.
  List<AudioTrack>? _audioQueue() {
    if (!widget._fromList) return null;
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
    return ZikrReaderPage(
      // Driven by [_currentZikr], refreshed in onPageChanged below, so the
      // shared chrome (title + audio action) tracks the visible zikr.
      zikr: _currentZikr,
      // Full slide order as the playback queue so the mini player can
      // auto-advance through it.
      queue: _audioQueue(),
      child: PdfZoomScope(
        onZoomChanged: _handleZoomChanged,
        child: SwipeBackPageView(
          controller: _pageController,
          itemCount: widget.zikrIds.length,
          swipeEnabled: _zoomedManuscripts.isEmpty,
          onPageChanged: (index) {
            setState(() => _updateCurrentZikr(index));
          },
          itemBuilder: (context, index) {
            final zikr = resolveZikr(widget.zikrIds[index]);
            switch (zikr?.kind) {
              case ZikrKind.hilyaNasab:
                // Manuscript body; owns its PdfControllerPinch lifecycle and
                // reports chrome intents to the enclosing ReaderScaffold.
                return PdfReaderContent.asset(zikrPdfAsset(zikr!));
              case ZikrKind.tareeqaSanad:
                return const TareeqaSanadContent();
              case ZikrKind.text:
              case null:
                return ZikrContentWidget(zikrId: widget.zikrIds[index]);
            }
          },
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
    // Show a friendly page instead of crashing when the id is unknown
    // (e.g. from search or a stale deep link).
    if (resolveZikr(zikrId) == null) {
      return SwipeBackDetector(
        child: Scaffold(
          appBar: AppBar(title: Text(zikrId)),
          body: const Center(
            child: Text(
              'لم يتم العثور على هذا الذكر',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      );
    }

    return SlidableZikrScreen.single(zikrId);
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
      // The reader runs under the home indicator; the last line scrolls
      // clear of it.
      padding: EdgeInsets.fromLTRB(
        16,
        7,
        16,
        7 + MediaQuery.paddingOf(context).bottom,
      ),
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
