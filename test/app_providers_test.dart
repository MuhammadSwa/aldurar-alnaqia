import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferencesService().init();
  });

  ProviderContainer freshContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('fontSizeProvider', () {
    test('defaults to 22 with no persisted value', () {
      expect(freshContainer().read(fontSizeProvider), 22);
    });

    test('preview updates state without persisting', () async {
      final container = freshContainer();
      container.read(fontSizeProvider.notifier).preview(30);
      expect(container.read(fontSizeProvider), 30);
      expect(SharedPreferencesService.getFontSize(), 22);

      // A fresh container still sees the old persisted value.
      expect(freshContainer().read(fontSizeProvider), 22);
    });

    test('change persists the new size', () async {
      final container = freshContainer();
      container.read(fontSizeProvider.notifier).change(28);
      expect(container.read(fontSizeProvider), 28);
      expect(freshContainer().read(fontSizeProvider), 28);
    });
  });

  group('bookmarksProvider', () {
    test('starts empty and reports membership', () {
      final container = freshContainer();
      expect(container.read(bookmarksProvider), isEmpty);
      expect(
        container.read(bookmarksProvider.notifier).isBookmarked('x'),
        isFalse,
      );
    });

    test('toggle adds then removes, returning the previous state', () {
      final container = freshContainer();
      final notifier = container.read(bookmarksProvider.notifier);

      expect(notifier.toggleBookmark('a'), isFalse);
      expect(container.read(bookmarksProvider), ['a']);
      expect(notifier.isBookmarked('a'), isTrue);

      expect(notifier.toggleBookmark('a'), isTrue);
      expect(container.read(bookmarksProvider), isEmpty);
    });

    test('toggles persist across containers', () {
      final container = freshContainer();
      container.read(bookmarksProvider.notifier).toggleBookmark('a');
      container.read(bookmarksProvider.notifier).toggleBookmark('b');
      expect(freshContainer().read(bookmarksProvider), ['a', 'b']);
    });
  });

  group('hijriOffsetProvider', () {
    test('defaults to 0 and persists set values', () {
      final container = freshContainer();
      expect(container.read(hijriOffsetProvider), 0);
      container.read(hijriOffsetProvider.notifier).set(-1);
      expect(freshContainer().read(hijriOffsetProvider), -1);
    });
  });

  group('yousriaBeginningProvider', () {
    DateTime midnight(DateTime d) => DateTime(d.year, d.month, d.day);

    test('relativeDay counts back from today and clamps to the cycle', () {
      final container = freshContainer();
      final notifier = container.read(yousriaBeginningProvider.notifier);

      expect(notifier.relativeDay(), 0);

      SharedPreferencesService.setYousriaBeginning(
        DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(freshContainer().read(yousriaBeginningProvider.notifier)
          .relativeDay(), 3);

      SharedPreferencesService.setYousriaBeginning(
        DateTime.now().subtract(const Duration(days: 30)),
      );
      expect(freshContainer().read(yousriaBeginningProvider.notifier)
          .relativeDay(), 5);

      SharedPreferencesService.setYousriaBeginning(
        DateTime.now().add(const Duration(days: 2)),
      );
      expect(freshContainer().read(yousriaBeginningProvider.notifier)
          .relativeDay(), 0);
    });

    test('setBeginning truncates to midnight', () async {
      final container = freshContainer();
      await container.read(yousriaBeginningProvider.notifier).setBeginning(
            DateTime(2024, 6, 15, 18, 30),
          );
      expect(
        container.read(yousriaBeginningProvider),
        DateTime(2024, 6, 15),
      );
    });

    test('setRelativeDay offsets from today', () async {
      final container = freshContainer();
      await container
          .read(yousriaBeginningProvider.notifier)
          .setRelativeDay(2);
      expect(
        midnight(container.read(yousriaBeginningProvider)),
        midnight(DateTime.now().subtract(const Duration(days: 2))),
      );
    });
  });

  group('fileOpenActionProvider', () {
    test('defaults to ask', () {
      expect(freshContainer().read(fileOpenActionProvider), FileOpenAction.ask);
    });

    test('fromString maps known values and falls back to ask', () {
      expect(FileOpenAction.fromString('open'), FileOpenAction.open);
      expect(FileOpenAction.fromString('download'), FileOpenAction.download);
      expect(FileOpenAction.fromString('ask'), FileOpenAction.ask);
      expect(FileOpenAction.fromString(null), FileOpenAction.ask);
      expect(FileOpenAction.fromString('stream'), FileOpenAction.ask);
    });

    test('toStorageString round-trips every action', () {
      for (final action in FileOpenAction.values) {
        expect(FileOpenAction.fromString(action.toStorageString()), action);
      }
    });

    test('set persists across containers', () async {
      final container = freshContainer();
      await container
          .read(fileOpenActionProvider.notifier)
          .set(FileOpenAction.download);
      expect(
        freshContainer().read(fileOpenActionProvider),
        FileOpenAction.download,
      );
    });
  });

}
