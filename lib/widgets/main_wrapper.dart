import 'package:aldurar_alnaqia/audio/audio_controller.dart' show audioProvider;
import 'package:aldurar_alnaqia/audio/widgets/audio_mini_player.dart';
import 'package:aldurar_alnaqia/widgets/my_drawer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Key of the single [Scaffold] in [MainWrapper] that owns the app drawer
/// and the bottom [NavigationBar].
final rootScaffoldKey = GlobalKey<ScaffoldState>(debugLabel: 'rootDrawer');

class MainWrapper extends ConsumerWidget {
  const MainWrapper({
    required this.navigationShell,
    super.key,
  });
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void goBranch(int index) {
      rootScaffoldKey.currentState?.closeDrawer();

      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    final showAudioBar =
        ref.watch(audioProvider.select((state) => state.isVisible));
    // Selected tab icon color contrasts with the primary indicator pill.
    final selectedIconColor = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 1000),
          child: Scaffold(
            key: rootScaffoldKey,
            drawer: const MyDrawer(),
            // Keep the bottom NavigationBar pinned: the keyboard overlays
            // it instead of lifting it above the keyboard.
            resizeToAvoidBottomInset: false,
            body: Center(
              child: Column(
                children: [
                  Expanded(
                    child: navigationShell,
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
              onDestinationSelected: goBranch,
              selectedIndex: navigationShell.currentIndex,
            ),
          ),
        ),
      ),
    );
  }
}
