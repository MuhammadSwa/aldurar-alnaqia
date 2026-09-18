import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/helia_nasab_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/play_audio_btn_zikr_page.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/widgets/bayt_widget.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/widgets/zikr_inline_text.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/zikr_blocks.dart';

class SlidableZikrScreen extends StatefulWidget {
  final List<String> zikrIds;
  final int initialIndex;

  const SlidableZikrScreen({
    super.key,
    required this.zikrIds,
    required this.initialIndex,
  });

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
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentZikr.title),
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
      ),
      body: PageView.builder(
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
            default:
              return ZikrContentWidget(zikrId: widget.zikrIds[index]);
          }
        },
      ),
    );
  }
}

class ZikrScreen extends StatelessWidget {
  const ZikrScreen({
    super.key,
    required this.zikrId,
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
    final Zikr? zikr = resolveZikr(zikrId);

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

    return Scaffold(
      appBar: AppBar(
        actions: [
          PlayAudioBtnZikrPage(
            id: zikr.id,
            title: zikr.title,
            url: zikr.url,
          ),
        ],
        title: Text(
          zikr.title,
        ),
      ),
      body: ZikrContentWidget(
        zikrId: zikr.id,
      ),
    );
  }
}

class ZikrContentWidget extends ConsumerWidget {
  const ZikrContentWidget({super.key, required this.zikrId});
  final String zikrId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Zikr? zikr = resolveZikr(zikrId);
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7),
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
