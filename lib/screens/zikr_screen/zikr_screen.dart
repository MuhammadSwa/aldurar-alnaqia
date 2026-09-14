import 'package:aldurar_alnaqia/models/consts/alhadra_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/play_audio_btn_zikr_page.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/widgets/bayt_widget.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/widgets/zikr_inline_text.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/zikr_blocks.dart';
import 'package:pdfrx/pdfrx.dart';

class SlidableZikrScreen extends StatefulWidget {
  final List<String> allTitles;
  final int initialIndex;

  const SlidableZikrScreen({
    super.key,
    required this.allTitles,
    required this.initialIndex,
  });

  @override
  State<SlidableZikrScreen> createState() => _SlidableZikrScreenState();
}

class _SlidableZikrScreenState extends State<SlidableZikrScreen> {
  late PageController _pageController;
  late String _currentTitle;
  late Zikr _currentZikr;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _updateCurrentZikr(widget.initialIndex);
  }

  void _updateCurrentZikr(int index) {
    _currentTitle = widget.allTitles[index];
    _currentZikr =
        allAzkar.azkarCategMap[_currentTitle] ?? allAzkar.azkarCategMap.values.first;
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
        title: Text(_currentTitle),
        actions: [
          // The action button updates reactively based on the current Zikr
          PlayAudioBtnZikrPage(
            id: _currentZikr.title,
            title: _currentZikr.title,
            url: _currentZikr.url,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.allTitles.length,
        // This callback updates the AppBar title when you swipe to a new page
        onPageChanged: (index) {
          setState(() {
            _updateCurrentZikr(index);
          });
        },
        // The builder creates the content widget for each Zikr
        itemBuilder: (context, index) {
          if (widget.allTitles[index] == alhyliaAndNasab.title) {
            return PdfViewer.asset(
                'assets/pdfs/${widget.allTitles[index]}.pdf');
          }
          return ZikrContentWidget(
            title: widget.allTitles[index],
          );
        },
      ),
    );
  }
}

class ZikrScreen extends StatelessWidget {
  const ZikrScreen({
    super.key,
    required this.title,
    this.titles,
    this.index,
  });

  final String title;
  final int? index;
  final List<String>? titles;

  @override
  Widget build(BuildContext context) {
    if (titles != null && index != null) {
      return SlidableZikrScreen(allTitles: titles!, initialIndex: index!);
    }
    // Find the specific Zikr data using the title; show a friendly page
    // instead of crashing when the title is unknown (e.g. from search).
    final Zikr? zikr = allAzkar.azkarCategMap[title];

    if (zikr == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(
          child: Text('لم يتم العثور على هذا الذكر',
              style: TextStyle(fontSize: 18)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          PlayAudioBtnZikrPage(
            id: zikr.title,
            title: zikr.title,
            url: zikr.url,
          ),
        ],
        title: Text(
          title,
        ),
      ),
      body: ZikrContentWidget(
        title: zikr.title,
      ),
    );
  }
}

class ZikrContentWidget extends ConsumerWidget {
  const ZikrContentWidget({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Zikr zikr = allAzkar.azkarCategMap[title]!;
    final fontSize = ref.watch(fontSizeProvider);
    final blocks = parseZikrBlocks(zikr.content);

    return SingleChildScrollView(
        child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (zikr.notes != '') ...[
            ZikrInlineText(
              text: zikr.notes,
              textAlign: TextAlign.start,
              sizeFactor: .7,
            ),
            const Divider(),
          ],
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0)
              SizedBox(
                  height: _gapBefore(blocks[i - 1], blocks[i], fontSize)),
            _blockWidget(blocks[i]),
          ],
          if (zikr.footer != '') ...[
            const Divider(),
            ZikrInlineText(
              text: zikr.footer,
              textAlign: TextAlign.start,
              sizeFactor: .7,
            ),
          ],
        ],
      ),
    ));
  }

  /// Tighter rhythm inside a qasida; airier spacing around prose/headings.
  double _gapBefore(ZikrBlock previous, ZikrBlock current, double fontSize) {
    if (previous is BaytBlock && current is BaytBlock) {
      return fontSize * .45;
    }
    return fontSize * .7;
  }

  Widget _blockWidget(ZikrBlock block) {
    return switch (block) {
      ProseBlock(:final text) => ZikrInlineText(text: text),
      HeadingBlock(:final text) => ZikrInlineText(
          text: text,
          textAlign: TextAlign.center,
          sizeFactor: 1.15,
          bold: true,
        ),
      BaytBlock(:final sadr, :final ajz) =>
        BaytWidget(sadr: sadr, ajz: ajz),
    };
  }
}
