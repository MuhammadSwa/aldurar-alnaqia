import 'package:aldurar_alnaqia/common/helpers/arabic_back_material_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BackButton tooltip overridden to Arabic', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          ArabicBackMaterialLocalizationsDelegate(),
        ],
        home: Scaffold(appBar: AppBar(title: const Text('a'))),
      ),
    );
    final ctx = tester.element(find.byType(Scaffold));
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(appBar: AppBar(title: const Text('b'))),
      ),
    );
    await tester.pumpAndSettle();
    final backBtn = find.byType(BackButton);
    expect(backBtn, findsOneWidget);
    expect(tester.widget<BackButton>(backBtn).tooltip, isNull);
    // BackButton builds an IconButton with the localized tooltip.
    final iconBtn = find.byType(IconButton);
    expect(iconBtn, findsWidgets);
    final tooltips = tester
        .widgetList<IconButton>(iconBtn)
        .map((b) => b.tooltip)
        .toList();
    // ignore: avoid_print
    print('TOOLTIPS:$tooltips');
    expect(tooltips, contains('رجوع'));
  });
}
