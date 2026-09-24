import 'package:aldurar_alnaqia/common/widgets/app_tile.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/bookmark_button.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/zikr_list_view_tile_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferencesService().init();
  });
  group('AppTile', () {
    testWidgets('renders title, leading, and default trailing circular arrow',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTile(
              title: 'اختبار العنوان',
              subtitle: 'عنوان فرعي',
              leading: const AppTileLeadingIcon(icon: Icons.bookmark),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('اختبار العنوان'), findsOneWidget);
      expect(find.text('عنوان فرعي'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.text('اختبار العنوان'));
      expect(tapped, isTrue);
    });

    testWidgets('supports custom trailing widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTile(
              title: 'بلا زر تتبع',
              trailing: SizedBox(key: ValueKey('custom-trailing')),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('custom-trailing')), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });

  group('BookmarkButton with AppTile', () {
    testWidgets('toggles bookmark state independently of tile onTap',
        (tester) async {
      var tileTapped = false;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AppTile(
                title: 'ذكر تجريبي',
                leading: const BookmarkButton(
                  bookmarkId: 'test-zikr',
                  showSnackBarBool: false,
                ),
                onTap: () => tileTapped = true,
              ),
            ),
          ),
        ),
      );

      // Initially unbookmarked
      expect(find.byIcon(Icons.bookmark_outline_rounded), findsOneWidget);
      expect(
        container.read(bookmarksProvider).contains('test-zikr'),
        isFalse,
      );

      // Tap the bookmark button directly
      await tester.tap(find.byType(BookmarkButton));
      await tester.pumpAndSettle();

      // Bookmark toggled to bookmarked
      expect(
        container.read(bookmarksProvider).contains('test-zikr'),
        isTrue,
      );
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);

      // Outer tile tap should NOT have fired
      expect(tileTapped, isFalse);

      // Tap the outer tile (outside the bookmark button)
      await tester.tap(find.text('ذكر تجريبي'));
      await tester.pumpAndSettle();
      expect(tileTapped, isTrue);
    });

    testWidgets('renders ZikrListViewTile with resolved title and AppTile',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ZikrListViewTile(
                zikrId: weekCollectionBookmarkId,
                target: WeekCollectionTarget(ZikrBranch.awrad),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppTile), findsOneWidget);
      expect(find.text('أوراد الأسبوع'), findsOneWidget);
      expect(find.byType(BookmarkButton), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
