import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aldurar_alnaqia/audio/widgets/audio_mini_player.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:aldurar_alnaqia/audio/audio_controller.dart' show audioProvider;
import 'package:aldurar_alnaqia/widgets/my_drawer.dart';

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
  void _goBranch(int index) {
    // The drawer and the NavigationBar share this Scaffold, so closing is
    // synchronous state — no animation delay is needed before switching
    // branches (replaces the old DrawerRegistry + 300ms workaround).
    ref.read(rootScaffoldKeyProvider).currentState?.closeDrawer();

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
    // Global RTL comes from MaterialApp.builder in main.dart.
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 1000),
          child: Scaffold(
            key: ref.watch(rootScaffoldKeyProvider),
            drawer: const MyDrawer(),
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
                  selectedIcon: Icon(Icons.home, color: selectedIconColor),
                  icon: const Icon(Icons.home_outlined),
                  label: 'الرئيسية',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.timer_outlined),
                  selectedIcon: Icon(Icons.timer, color: selectedIconColor),
                  label: 'مواقيت الصلاة',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.list, color: selectedIconColor),
                  icon: const Icon(Icons.list_outlined),
                  label: 'الأوراد',
                ),
                NavigationDestination(
                  selectedIcon: Icon(Icons.book, color: selectedIconColor),
                  icon: const Icon(Icons.book_outlined),
                  label: 'المكتبة',
                ),
              ],
              onDestinationSelected: (index) {
                _goBranch(index);
              },
              selectedIndex: widget.navigationShell.currentIndex,
            ),
          ),
        ),
      ),
    );
  }
}
