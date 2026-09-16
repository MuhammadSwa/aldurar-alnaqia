import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aldurar_alnaqia/audio/widgets/audio_mini_player.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/audio/audio_controller.dart' show audioProvider;
import 'package:aldurar_alnaqia/common/helpers/logger.dart';

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
    // Close all drawers before navigating. The short delay lets the drawer
    // close animation finish so the branch switch doesn't flicker.
    try {
      final drawerRegistry = ref.read(drawerRegistryProvider);

      if (drawerRegistry.hasOpenDrawer) {
        // Close instantly without animation to avoid flickering
        drawerRegistry.closeAllDrawers();
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      logWarn('Drawer registry unavailable in _goBranch: $e');
    }

    if (!mounted) return;
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showAudioBar =
        ref.watch(audioProvider.select((state) => state.isVisible));
    // Selected tab icon color contrasts with the primary indicator pill.
    final selectedIconColor = Theme.of(context).colorScheme.onPrimary;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 1000),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              // Keep the bottom NavigationBar pinned: the keyboard overlays
              // it instead of lifting it above the keyboard.
              resizeToAvoidBottomInset: false,
              body: Center(
                child: Column(
                  children: [
                    Expanded(
                      child: widget.navigationShell,
                    ),
                    if (showAudioBar) const AudioMiniPlayer(),
                  ],
                ),
              ),
              bottomNavigationBar: NavigationBar(
                indicatorShape: const StadiumBorder(),
                destinations: [
                  NavigationDestination(
                      selectedIcon:
                          Icon(Icons.home, color: selectedIconColor),
                      icon: const Icon(Icons.home_outlined),
                      label: 'الرئيسية',),
                  NavigationDestination(
                      icon: const Icon(Icons.timer_outlined),
                      selectedIcon:
                          Icon(Icons.timer, color: selectedIconColor),
                      label: 'مواقيت الصلاة',),
                  NavigationDestination(
                      selectedIcon:
                          Icon(Icons.list, color: selectedIconColor),
                      icon: const Icon(Icons.list_outlined),
                      label: 'الأوراد',),
                  NavigationDestination(
                      selectedIcon:
                          Icon(Icons.book, color: selectedIconColor),
                      icon: const Icon(Icons.book_outlined),
                      label: 'المكتبة',),
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
