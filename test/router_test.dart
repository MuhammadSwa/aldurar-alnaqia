import 'package:flutter_test/flutter_test.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/router/app_router.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final router = AppRouter.createRouter();

  group('named locations round-trip path parameters exactly once', () {
    const idsWithTrickyCharacters = <String>[
      'wird-asas',
      'yousria-day-1',
      'salat-anmuzajiyya',
      'dalayil-hizb-1',
      'hilya-nasab',
      'sanad-tariqa',
    ];

    for (final id in idsWithTrickyCharacters) {
      test('"$id" survives encode -> decode', () {
        final location = router.namedLocation(
          'homeZikrPage',
          pathParameters: {'zikr': id},
        );

        final uri = Uri.parse(location);
        expect(uri.pathSegments.first, 'home');
        expect(uri.pathSegments[uri.pathSegments.length - 2], 'zikr');
        expect(uri.pathSegments.last, id);
      });
    }

    test('unknown title no longer resolves (id-only routes)', () {
      expect(resolveZikr('ورد الأساس'), isNull);
    });

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
                  ? {'collection': 'qasaed', 'zikr': 'banat-suad'}
                  : {'zikr': 'wird-asas'},
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
            pathParameters: {'collection': 'qasaed'},
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
