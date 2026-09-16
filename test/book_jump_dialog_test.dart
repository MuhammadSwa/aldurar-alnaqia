import 'package:aldurar_alnaqia/screens/library_screen/widgets/book_jump_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('jump dialog returns parsed page on انتقال', (tester) async {
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showBookJumpDialog(
                  context,
                  currentPage: 3,
                  total: 100,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('الانتقال إلى صفحة'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.text('انتقال'));
    await tester.pumpAndSettle();

    expect(result, 42);
  });

  testWidgets('jump dialog cancel returns null', (tester) async {
    int? result = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showBookJumpDialog(
                  context,
                  currentPage: 3,
                  total: 100,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
