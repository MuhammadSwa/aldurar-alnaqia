import 'package:aldurar_alnaqia/screens/social_screen/social_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class MockUrlLauncherPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final List<String> launchedUrls = [];
  final List<LaunchOptions> launchOptions = [];
  final Set<String> failUrls = {};

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    launchOptions.add(options);
    return !failUrls.contains(url);
  }
}

/// Titles and URLs in the order SocialScreen lists them. Kept in sync with
/// the `_sites` table in social_screen.dart so a removed/edited link fails
/// loudly instead of going stale.
const expectedSites = <Map<String, String>>[
  {
    'title': 'الصفحة الرسمية لفضيلة أ.د. يسري جبر',
    'url': 'https://www.facebook.com/dr.yosrygabr/',
  },
  {
    'title': 'صفحة أوراد الطريقة اليسرية الصديقية',
    'url': 'https://www.facebook.com/Awrad.Dryosry',
  },
  {
    'title': 'المجموعة الرسمية لنشر دروس وأخبار فضيلة أ.د. يسري جبر',
    'url': 'https://www.facebook.com/groups/245819711389',
  },
  {
    'title': 'Dr. Yosry Gabr in English',
    'url':
        'https://www.facebook.com/people/Dr-Yosry-Gabr-in-English/61574856976137',
  },
  {
    'title': 'قناة اليوتيوب',
    'url': 'https://www.youtube.com/c/MohamadSameh',
  },
  {
    'title': 'دروس د.يسري جبر',
    'url': 'https://youtube.com/@dryosrylectures?si=hzAsCiFuwVLpvTEb',
  },
  {
    'title': 'حساب الساوند كلاود',
    'url': 'https://soundcloud.com/dryosrygabr',
  },
  {
    'title': 'قناة التليجرام',
    'url': 'https://t.me/DrYosryGabr',
  },
  {
    'title': 'صفحة الانستجرام',
    'url': 'http://www.instagram.com/DrYosryGabr',
  },
  {
    'title': 'Dr. Yosry Gabr in English',
    'url': 'https://www.instagram.com/dryosrygabr_en/',
  },
  {
    'title': 'صفحة التيك توك',
    'url': 'http://www.tiktok.com/@dryosrygabr',
  },
  {
    'title': 'حساب التويتر 𝕏',
    'url': 'http://www.twitter.com/DrYosryGabr',
  },
  {
    'title': 'مسجد الأشراف',
    'url': 'https://maps.app.goo.gl/8Eog1x4g8nQqtKSc9',
  },
  {
    'title': 'توصية ورجاء وأمر لجميع المتابعين',
    'url': 'https://youtu.be/KbQnZN5x2-g',
  },
  {
    'title': 'كيفية قراءة الأوراد',
    'url': 'https://youtu.be/IyrWSL4jd00',
  },
];

void main() {
  late MockUrlLauncherPlatform mockLauncher;

  setUp(() {
    mockLauncher = MockUrlLauncherPlatform();
    UrlLauncherPlatform.instance = mockLauncher;
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SocialScreen()),
    );
  }

  group('SocialScreen link table', () {
    testWidgets('renders header and one tile per site', (tester) async {
      await pumpScreen(tester);

      expect(
        find.text('الصفحات الرسمية لفضيلة أ.د. يسري جبر'),
        findsWidgets,
      );
      expect(find.byType(ListTile), findsNWidgets(expectedSites.length));
    });

    testWidgets('every site url is unique and parseable', (tester) async {
      await pumpScreen(tester);

      final urls = expectedSites.map((s) => s['url']!).toList();
      expect(urls.toSet(), hasLength(urls.length));
      for (final url in urls) {
        expect(() => Uri.parse(url), returnsNormally);
      }
      // The screen must actually show every expected title.
      for (final site in expectedSites) {
        expect(find.text(site['title']!), findsWidgets);
      }
    });

    testWidgets('tapping each tile launches its url externally',
        (tester) async {
      await pumpScreen(tester);

      for (var i = 0; i < expectedSites.length; i++) {
        final tile = find.byType(ListTile).at(i);
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pump();
      }

      expect(
        mockLauncher.launchedUrls,
        expectedSites.map((s) => s['url']).toList(),
      );
      for (final options in mockLauncher.launchOptions) {
        expect(options.mode, PreferredLaunchMode.externalApplication);
      }
    });

    testWidgets('tapping trailing icon launches the same url', (tester) async {
      await pumpScreen(tester);

      for (final i in [0, expectedSites.length - 1]) {
        final iconButton = find.byType(IconButton).at(i);
        await tester.ensureVisible(iconButton);
        await tester.tap(iconButton);
        await tester.pump();
        expect(
          mockLauncher.launchedUrls.last,
          expectedSites[i]['url'],
        );
      }
    });

    testWidgets('a failed launch does not throw', (tester) async {
      mockLauncher.failUrls.add(expectedSites.first['url']!);
      await pumpScreen(tester);

      await tester.ensureVisible(find.byType(ListTile).first);
      await tester.tap(find.byType(ListTile).first);
      await tester.pump();

      expect(
        mockLauncher.launchedUrls,
        contains(expectedSites.first['url']),
      );
    });
  });
}
