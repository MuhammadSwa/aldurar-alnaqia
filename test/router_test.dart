import 'package:flutter_test/flutter_test.dart';
import 'package:aldurar_alnaqia/router/app_router.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final router = AppRouter.createRouter();

  group('named locations round-trip Arabic path parameters exactly once', () {
    const titlesWithTrickyCharacters = <String>[
      'ورد يوم الإثنين',
      'الحضرة الصديقية',
      'صلوات مختارة على النبي ﷺ',
      'ورد عصر الجمعة (تقرأ مرة)',
      '100% مضمونة؟',
    ];

    for (final title in titlesWithTrickyCharacters) {
      test('"$title" survives encode -> decode', () {
        final location = router.namedLocation(
          'homeZikrPage',
          pathParameters: {'zikr': title},
        );

        final uri = Uri.parse(location);
        // Uri.pathSegments returns percent-decoded segments. Equaling the
        // raw title proves go_router encoded it exactly ONCE (a manually
        // pre-encoded or double-encoded value would not round-trip).
        expect(uri.pathSegments.first, 'home');
        expect(uri.pathSegments[uri.pathSegments.length - 2], 'zikr');
        expect(uri.pathSegments.last, title);
      });
    }

    test('pdf viewer book title round-trips', () {
      const bookTitle =
          'الدرر النقية في أوراد الطريقة اليسرية الصديقية الشاذلية';
      final location = router.namedLocation(
        RouteNames.pdfViewer,
        pathParameters: {'bookTitle': bookTitle},
      );
      final uri = Uri.parse(location);
      expect(uri.pathSegments.last, bookTitle);
    });
  });

  group('every generated zikr page name is registered', () {
    final expectedPrefixes = <String>[
      'home',
      'awrad',
      RouteNames.todayZikrPagePrefix,
      for (var day = 0; day < 8; day++) ...[
        RouteNames.weekCollectionDay(ZikrBranch.home, day),
        RouteNames.weekCollectionDay(ZikrBranch.awrad, day),
      ],
      RouteNames.zikrCollection(ZikrBranch.home),
      RouteNames.zikrCollection(ZikrBranch.awrad),
    ];

    for (final prefix in expectedPrefixes) {
      test('name "${RouteNames.zikrPage(prefix)}" exists', () {
        // namedLocation asserts on unknown route names.
        expect(
          () {
            final name = RouteNames.zikrPage(prefix);
            final isCollectionNested =
                prefix == RouteNames.zikrCollection(ZikrBranch.home) ||
                    prefix == RouteNames.zikrCollection(ZikrBranch.awrad);
            return router.namedLocation(
              name,
              pathParameters: isCollectionNested
                  ? {'collection': 'قصائد', 'zikr': 'x'}
                  : {'zikr': 'x'},
            );
          },
          returnsNormally,
        );
      });
    }
  });

  group('collection and week-collection routes resolve', () {
    test('zikrCollection named route exists for both branches', () {
      for (final branch in ZikrBranch.values) {
        expect(
          () => router.namedLocation(
            RouteNames.zikrCollection(branch),
            pathParameters: {'collection': 'قصائد'},
          ),
          returnsNormally,
        );
        expect(
          () => router.namedLocation(
            RouteNames.weekCollection(branch),
          ),
          returnsNormally,
        );
      }
    });

    test('day wird paths are ASCII-safe', () {
      for (final branch in ZikrBranch.values) {
        expect(AppRoutes.dayWirdPath(branch, 3), matches(RegExp(r'^/[a-zA-Z]+/weekCollection/3$')));
      }
    });
  });
}
