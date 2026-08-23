import 'package:aldurar_alnaqia/models/consts/alhadra_collection.dart';
import 'package:easy_rich_text/easy_rich_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/play_audio_btn_zikr_page.dart';
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
    final fontFamily = ref.watch(fontFamilyProvider);
    return SingleChildScrollView(
        child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (zikr.notes != '') ...{
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zikr.notes,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(fontSize: fontSize * .7),
                ),
                const Divider()
              ],
            ),
          },
              EasyRichText(
                zikr.content,
                defaultStyle: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(fontSize: fontSize),
                patternList: [
                  // === footer Numbering ===

                  EasyRichTextPattern(
                    // recognizer: TapGestureRecognizer()
                    // ..onTap = () {
                    //   // TODO:scroll down to the excat footer
                    //   // first how to know the exact number?
                    //   // make me use (?) icon after the number and tap on that?,
                    //   // prefixInlineSpan: const TextSpan(text: 'down'),
                    //   // but how to know the exact number
                    //   // make in setting if to enable scroll if tapped
                    // },
                    // the line shouldn't start or end with F,X so not to interfere with rhymes matching
                    targetString: r'\[\^[0-9]+\]',

                    // r'(?<!\bF)[^\n]*\b\[\^[0-9]+\]\b',
                    // r'^[?!F].*\[\^[0-9]+\][?=.*$][?!.*X$]',
                    // r'^[?!F].*\[\^[0-9]+\][?!.*X$]',
                    // r'[^X][$F]\[\^[0-9]+\]',
                    // r'[^?!F].*[^1] .*[$?!X]',

                    // r'^(?!F)\[\^[0-9]+\]$(?!X)',

                    matchBuilder: (context, match) {
                      final text = match?[0]?.replaceAll('^', '');
                      // TODO: make it 50% transparent?
                      // better styling
                      return TextSpan(
                        text: text,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall!
                            .copyWith(fontSize: fontSize * .7),
                      );
                    },
                  ),

                  // === quarn verses and hadith ===

                  EasyRichTextPattern(
                    targetString: [
                      '«[^»]+»',
                    ],
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).textTheme.bodyMedium!.color,
                    ),
                  ),
                  EasyRichTextPattern(
                    targetString: [
                      r'﴿[^﴾]+﴾',
                      // '«[^»]+»',
                      'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ'
                    ],
                    style: TextStyle(
                      fontFamily: fontFamily,
                      color: Theme.of(context).textTheme.bodyMedium!.color,
                    ),
                  ),

                  // TODO: better patternt matching and beter replacing.
                  EasyRichTextPattern(
                    targetString:
                        r'F[^X][\u0600-\u06FF\s0-9\[\]\^]+__[\u0600-\u06FF\s0-9\[\]\^]+X',
                    matchBuilder: (context, match) {
                      final rhymes = match?[0]!
                          .replaceAll('F', '')
                          .replaceAll('X', '')
                          .split('__');
                      return TextSpan(
                        children: [
                          WidgetSpan(
                            child: RhymesWidget(
                                first: rhymes![0], second: rhymes[1]),
                          ),
                        ],
                      );
                    },
                    style: const TextStyle(color: Colors.green),
                  ),

                  EasyRichTextPattern(
                    targetString: r'[0-9/]*\.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(fontSize: fontSize),
                  ),
                  EasyRichTextPattern(
                    targetString: [
                      r'\[[\u0600-\u06FF\s]+:[^\]]+[0-9]\]',
                      r'\[تقرأ مرة واحدة للمتعجل\]',
                      // r'\(سبع مرات\)',
                      // r'\(ثلاثًا\)',
                    ],
                    // style: Theme.of(context).textTheme.labelSmall!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(fontSize: fontSize * .7),
                    // style: TextStyle(color: Colors.green),
                  ),

                  // TODO: Theme:
                  EasyRichTextPattern(
                    targetString: '##[$araLettersRegex$space()ﷺ]+',
                    matchBuilder: (context, match) {
                      final text = match?[0]?.replaceAll('##', '');
                      // TODO: Theme
                      return TextSpan(
                        text: text,
                        // TODO: theme
                        // font from shared_prefs
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall!.color,
                            fontSize: 26),
                      );
                    },
                  )
                ],
                textAlign: TextAlign.justify,
              ),
              if (zikr.footer != '') ...{
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    EasyRichText(
                      zikr.footer,
                      defaultStyle: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(fontSize: fontSize * .7),
                      patternList: [
                        EasyRichTextPattern(
                          targetString: [
                            r'﴿[^﴾]+﴾',
                            // '«[^»]+»',
                            'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
                          ],
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(
                                  fontSize: fontSize * .7,
                                  fontFamily: fontFamily),
                        )
                      ],
                    )
                  ],
                ),
              }
            ],
          ),
        ));
  }
}

const String space = '\u0020';
const String araLettersRegex = '\u0600-\u06FF';

class RhymesWidget extends ConsumerWidget {
  const RhymesWidget({super.key, required this.first, required this.second});
  final String first, second;

  EasyRichTextPattern _buildPattern(BuildContext context, WidgetRef ref) {
    return EasyRichTextPattern(
      targetString: r'\[\^\^[0-9]+\]',
      matchBuilder: (context, match) {
        final text = match?[0]?.replaceAll('^', '');
        final fontSize = ref.watch(fontSizeProvider);
        return TextSpan(
          text: text,
          style: Theme.of(context)
              .textTheme
              .bodySmall!
              .copyWith(fontSize: fontSize * .7),
        );
      },
    );
  }

  Widget _buildRhyme(BuildContext context, WidgetRef ref, String text,
      double fontSize, String alignment) {
    return Align(
      alignment:
          alignment == 'right' ? Alignment.centerRight : Alignment.centerLeft,
      child: EasyRichText(
        defaultStyle: Theme.of(context)
            .textTheme
            .bodyMedium!
            .copyWith(fontSize: fontSize),
        text,
        textAlign: alignment == 'right' ? TextAlign.right : TextAlign.left,
        patternList: [_buildPattern(context, ref)],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(fontSizeProvider);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRhyme(context, ref, first, fontSize, 'right'),
          _buildRhyme(context, ref, second, fontSize, 'left'),
        ],
      ),
    );
  }
}
