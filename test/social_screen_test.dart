// ignore_for_file: depend_on_referenced_packages
import 'package:aldurar_alnaqia/screens/social_screen/social_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class MockUrlLauncherPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}

void main() {
  late MockUrlLauncherPlatform mockLauncher;

  setUp(() {
    mockLauncher = MockUrlLauncherPlatform();
    UrlLauncherPlatform.instance = mockLauncher;
  });

  testWidgets('tapping ListTile text launches url', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SocialScreen(),
      ),
    );

    // Tap on the text of the first site
    final textFinder = find.text('الصفحة الرسمية لفضيلة أ.د. يسري جبر');
    expect(textFinder, findsOneWidget);

    await tester.tap(textFinder);
    await tester.pump();

    expect(mockLauncher.launchedUrls, contains('https://www.facebook.com/dr.yosrygabr/'));
  });

  testWidgets('tapping trailing icon launches url', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SocialScreen(),
      ),
    );

    // Tap on the icon button of the first site
    final iconButtonFinder = find.byType(IconButton).first;
    expect(iconButtonFinder, findsWidgets);

    await tester.tap(iconButtonFinder);
    await tester.pump();

    expect(mockLauncher.launchedUrls, contains('https://www.facebook.com/dr.yosrygabr/'));
  });
}
