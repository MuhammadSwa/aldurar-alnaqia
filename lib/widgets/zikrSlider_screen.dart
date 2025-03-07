import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yosria/models/consts/alhadra_collection.dart';
import 'package:yosria/screens/zikr_screen/zikr_screen.dart';
import 'package:yosria/widgets/azkarListView/helia_nasab_screen.dart';

class ZikrsliderScreen extends StatelessWidget {
  const ZikrsliderScreen(this.titles, {super.key});
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PageView.builder(
        itemCount: titles.length,
        itemBuilder: (BuildContext context, int i) {
          if (titles[i] == alhyliaAndNasab.title) {
            return const HeliaNasabScreen();
          }
          return ZikrScreen(title: titles[i]);
        },
      ),
    );
  }
}

class AzkarSliderButton extends StatelessWidget {
  const AzkarSliderButton({super.key, required this.titles});
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        context.push('/slider', extra: titles);
      },
      icon: const Icon(Icons.slideshow),
    );
  }
}

class FloatingSliderBtn extends StatelessWidget {
  const FloatingSliderBtn({super.key, required this.titles});
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        context.push('/slider', extra: titles);
      },
      child: const Icon(Icons.swipe),
    );
  }
}
