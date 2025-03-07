import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:yosria/models/consts/alhadra_collection.dart';
import 'package:yosria/models/consts/orphans.dart';
import 'package:yosria/screens/zikr_screen/zikr_screen.dart';

class HeliaNasabScreen extends StatelessWidget {
  const HeliaNasabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = alhyliaAndNasab.title;
    return Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: Center(
          child: PdfViewer.asset('assets/pdfs/$title.pdf'),
        ));
  }
}

// TareeqaSanadScreen
//
class TareeqaSanadScreen extends StatelessWidget {
  const TareeqaSanadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = sanadAltareeqa.title;

    return Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Column(children: [
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxHeight: constraints.maxHeight * .9),
                  child: PdfViewer.asset(
                    'assets/pdfs/$title.pdf',
                    params: PdfViewerParams(layoutPages: (pages, params) {
                      final height = pages.fold(
                        0.0,
                        (prev, page) {
                          return max(prev, page.height);
                          // return max(prev, page.height) + params.margin * 2;
                        },
                      );
                      final pageLayouts = <Rect>[];
                      double x = params.margin;
                      // TODO: replace for to for in else where
                      for (final page in pages) {
                        // page. = PdfPageRotation.clockwise180;
                        pageLayouts.add(
                          Rect.fromLTWH(x, (height - page.height), page.width,
                              page.height),
                        );
                        x += page.width + params.margin;
                      }
                      return PdfPageLayout(
                          pageLayouts: pageLayouts,
                          documentSize: Size(x, height));
                    }),
                  ),
                ),
                ZikrContentWidget(
                  title: title,
                ),
              ]),
            );
          },
        ));
  }
}
