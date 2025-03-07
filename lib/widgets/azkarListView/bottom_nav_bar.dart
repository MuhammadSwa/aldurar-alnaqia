import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yosria/screens/award_list_screen/awrad_list_screen.dart';
import 'package:yosria/screens/home_screen/home_screen.dart';
import 'package:yosria/screens/library_screen/library_screen.dart';
import 'package:yosria/screens/prayer_timings_screen/prayer_timings_screen.dart';

class BottonNavBar extends StatelessWidget {
  BottonNavBar({super.key});
  final navBarController = Get.put(NavBarController());
  BottomNavigationBarItem _buildBottomBarItem(
      Icon icon, Icon activeIcon, String label) {
    return BottomNavigationBarItem(
      activeIcon: activeIcon,
      icon: icon,
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NavBarController>(builder: (context) {
      return Scaffold(
        body: IndexedStack(
          index: navBarController.currentIndex.value,
          children: const [
            HomePage(),
            PrayerTimingsScreen(),
            AwradListScreen(),
            LibraryScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          showUnselectedLabels: true,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.green,
          currentIndex: navBarController.currentIndex.value,
          onTap: (index) {
            navBarController.changeIndex(index);
          },
          items: [
            _buildBottomBarItem(const Icon(Icons.home_outlined),
                const Icon(Icons.home_filled), 'الرئيسية'),
            _buildBottomBarItem(const Icon(Icons.timer_outlined),
                const Icon(Icons.timer), 'مواقيت الصلاة'),
            _buildBottomBarItem(const Icon(Icons.list_outlined),
                const Icon(Icons.list), 'الأوراد'),
            _buildBottomBarItem(const Icon(Icons.book_outlined),
                const Icon(Icons.book), 'المكتبة'),
          ],
        ),
      );
    });
  }
}

class NavBarController extends GetxController {
  final currentIndex = 0.obs;
  void changeIndex(int index) {
    currentIndex.value = index;
    update();
  }
}
