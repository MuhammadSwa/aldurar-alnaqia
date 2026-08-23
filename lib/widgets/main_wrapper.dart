import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aldurar_alnaqia/audioPlayer/audio_player.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

class MainWrapper extends ConsumerStatefulWidget {
  const MainWrapper({
    required this.navigationShell,
    super.key,
  });
  final StatefulNavigationShell navigationShell;
  @override
  ConsumerState<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends ConsumerState<MainWrapper> {
  void _goBranch(int index) async {
    // Close all drawers before navigating
    try {
      final drawerRegistry = ref.read(drawerRegistryProvider);

      if (drawerRegistry.hasOpenDrawer) {
        // Close instantly without animation to avoid flickering
        drawerRegistry.closeAllDrawers();
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (_) {
      // Registry not available; ignore
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioService = ref.watch(audioPlayerProvider);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 1000),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: Column(
                  children: [
                    Expanded(
                      child: widget.navigationShell,
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: audioService.urlNotifier,
                      builder: (context, url, _) {
                        if (url.isNotEmpty) {
                          return const AudioControllerWidget();
                        } else {
                          return Container();
                        }
                      },
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: NavigationBar(
                indicatorShape: const StadiumBorder(),
                destinations: const [
                  NavigationDestination(
                      selectedIcon: Icon(Icons.home, color: Colors.green),
                      icon: Icon(Icons.home_outlined),
                      label: 'الرئيسية'),
                  NavigationDestination(
                      icon: Icon(Icons.timer_outlined),
                      selectedIcon: Icon(Icons.timer, color: Colors.green),
                      label: 'مواقيت الصلاة'),
                  NavigationDestination(
                      selectedIcon: Icon(Icons.list, color: Colors.green),
                      icon: Icon(Icons.list_outlined),
                      label: 'الأوراد'),
                  NavigationDestination(
                      selectedIcon: Icon(Icons.book, color: Colors.green),
                      icon: Icon(Icons.book_outlined),
                      label: 'المكتبة'),
                ],
                onDestinationSelected: (index) {
                  _goBranch(index);
                },
                selectedIndex: widget.navigationShell.currentIndex,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
