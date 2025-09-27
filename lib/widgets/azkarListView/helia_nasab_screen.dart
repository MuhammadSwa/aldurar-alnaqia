import 'dart:math';
import 'package:aldurar_alnaqia/screens/zikr_screen/playAudio_btn_zikr_page.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:aldurar_alnaqia/models/consts/alhadra_collection.dart';
import 'package:aldurar_alnaqia/models/consts/orphans.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/zikr_screen.dart';

class HeliaNasabScreen extends StatelessWidget {
  const HeliaNasabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = alhyliaAndNasab.title;
    return Scaffold(
        appBar: AppBar(
          actions: [
            PlayAudioBtnZikrPage(
              id: title,
              title: title,
              url: alhyliaAndNasab.url,
            ),
          ],
          title: Text(title),
        ),
        body: Center(
          child: PdfViewer.asset('assets/pdfs/$title.pdf'),
        ));
  }
}

class TareeqaSanadScreen extends StatelessWidget {
  const TareeqaSanadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = sanadAltareeqa.title;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _buildBody(title),
    );
  }

  Widget _buildBody(String title) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            children: [
              _buildPdfContainer(title, constraints),
              ZikrContentWidget(title: title),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPdfContainer(String title, BoxConstraints constraints) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: constraints.maxHeight * 0.9,
      ),
      child: PdfViewer.asset(
        'assets/pdfs/$title.pdf',
        params: _createRtlPdfParams(),
      ),
    );
  }

  PdfViewerParams _createRtlPdfParams() {
    return PdfViewerParams(
      layoutPages: (pages, params) {
        return _createRtlPageLayout(pages, params);
      },
    );
  }

  PdfPageLayout _createRtlPageLayout(
      List<PdfPage> pages, PdfViewerParams params) {
    final height = _calculateMaxHeight(pages);
    final pageLayouts = <Rect>[];

    // Calculate total width needed for all pages
    double totalWidth = _calculateTotalWidth(pages, params);
    double x = totalWidth - params.margin;

    // Layout pages from right to left
    for (final page in pages) {
      x -= page.width;
      pageLayouts.add(
        Rect.fromLTWH(
          x,
          (height - page.height) / 2, // Center vertically
          page.width,
          page.height,
        ),
      );
      x -= params.margin;
    }

    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(totalWidth, height + params.margin * 2),
    );
  }

  double _calculateMaxHeight(List<PdfPage> pages) {
    return pages.fold(0.0, (maxHeight, page) => max(maxHeight, page.height));
  }

  double _calculateTotalWidth(List<PdfPage> pages, PdfViewerParams params) {
    final pagesWidth =
        pages.fold(0.0, (totalWidth, page) => totalWidth + page.width);
    return pagesWidth + (params.margin * (pages.length + 1));
  }
}
