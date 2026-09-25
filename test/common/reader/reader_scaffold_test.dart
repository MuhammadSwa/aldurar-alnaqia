import 'package:aldurar_alnaqia/common/reader/reader_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('preserves a nested PageView page when the device rotates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pageController = PageController();
    addTearDown(pageController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderScaffold(
          title: 'Reader',
          child: PageView(
            controller: pageController,
            children: const [Text('first zikr'), Text('second zikr')],
          ),
        ),
      ),
    );

    pageController.jumpToPage(1);
    await tester.pump();
    expect(find.text('second zikr'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(800, 400));
    await tester.pump();

    expect(find.text('second zikr'), findsOneWidget);
  });
}
