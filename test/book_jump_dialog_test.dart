import 'package:aldurar_alnaqia/screens/library_screen/book_temp_loader.dart';
import 'package:aldurar_alnaqia/screens/library_screen/widgets/book_jump_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Pumps a screen with an "open" button that shows the dialog, taps it,
  /// and returns the dialog's future (completes when it is dismissed).
  Future<Future<int?>> openDialog(
    WidgetTester tester, {
    int currentPage = 3,
    int total = 100,
  }) async {
    Future<int?>? dialogFuture;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                dialogFuture = showBookJumpDialog(
                  context,
                  currentPage: currentPage,
                  total: total,
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
    return dialogFuture!;
  }

  Future<int?> submitText(WidgetTester tester, String text) async {
    final pending = await openDialog(tester);
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('انتقال'));
    await tester.pumpAndSettle();
    return pending;
  }

  group('showBookJumpDialog', () {
    testWidgets('prefills the current page and hints the valid range',
        (tester) async {
      final pending = await openDialog(tester, currentPage: 3, total: 100);

      expect(find.widgetWithText(TextField, '3'), findsOneWidget);
      expect(find.text('من 1 إلى 100'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(await pending, isNull);
    });

    testWidgets('returns the parsed page on انتقال', (tester) async {
      expect(await submitText(tester, '42'), 42);
    });

    testWidgets('trims surrounding whitespace', (tester) async {
      expect(await submitText(tester, '  7 '), 7);
    });

    testWidgets('empty input dismisses with null', (tester) async {
      expect(await submitText(tester, ''), isNull);
      expect(find.text('الانتقال إلى صفحة'), findsNothing);
    });

    testWidgets('non-numeric input dismisses with null', (tester) async {
      expect(await submitText(tester, 'abc'), isNull);
      expect(find.text('الانتقال إلى صفحة'), findsNothing);
    });

    testWidgets('keyboard submit returns the parsed page', (tester) async {
      final pending = await openDialog(tester);
      await tester.enterText(find.byType(TextField), '9');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(await pending, 9);
    });

    testWidgets('cancel returns null', (tester) async {
      final pending = await openDialog(tester);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(await pending, isNull);
    });
  });

  group('BookTempLoader.parsePage', () {
    test('parses plain numbers', () {
      expect(BookTempLoader.parsePage('42'), 42);
    });

    test('trims whitespace', () {
      expect(BookTempLoader.parsePage('  7\n'), 7);
    });

    test('rejects empty and non-numeric input', () {
      expect(BookTempLoader.parsePage(''), isNull);
      expect(BookTempLoader.parsePage('   '), isNull);
      expect(BookTempLoader.parsePage('abc'), isNull);
      expect(BookTempLoader.parsePage('4.5'), isNull);
    });
  });
}
