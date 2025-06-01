import 'package:aldurar_alnaqia/screens/settings_screen/font_settings_widget.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/toggleThemeBtn_widget.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/yousriaBeginningDayDropdown_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 0,
      semanticLabel: 'القائمة الجانبية',
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المظهر',
                  // TODO: change using font theme
                  style: TextStyle(fontSize: 20),
                ),
                ToggleThemeBtn()
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: YousriaBeginningDayDropDown(),
          ),
          const FontSizeSettingsWidget(),
          const FontFamilySettingsWidget(),
          _buildDrawerItem(
              icon: const Icon(
                Icons.link,
                color: Colors.white,
                size: 20,
              ),
              title: 'الصفحات الرسمية',
              onTap: () {
                Navigator.pop(context);
                context.push('/social');
              }),

          _buildDrawerItem(
              icon: const Icon(
                Icons.cloud_download_rounded,
                color: Colors.white,
                size: 20,
              ),
              title: 'إدارة التحميلات',
              onTap: () {
                Navigator.pop(context);
                context.push('/downloadManager/0');
              }),
          _buildDrawerItem(
              icon: SvgPicture.asset(
                'assets/icons/youtube-icon-svgrepo-com.svg',
                semanticsLabel: 'youtube_icon',
                width: 24,
              ),
              title: 'كيفية قراءة الأوراد',
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse('https://youtu.be/IyrWSL4jd00'));
              }),

          _buildDrawerItem(
              icon: SvgPicture.asset(
                'assets/icons/youtube-icon-svgrepo-com.svg',
                semanticsLabel: 'youtube_icon',
                width: 24,
              ),
              title: 'أسئلة المتابعين',
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse(
                    'https://www.youtube.com/playlist?list=PLEkQk5xrP-tkGXuZ9atE3k_7it12rUPTs'));
              }),
          // _buildDrawerItem(
          //   icon: Icons.notifications_rounded,
          //   title: 'Notifications',
          //   onTap: () => Navigator.pop(context),
          // ),
          // const SizedBox(height: 20),
          // _buildDivider(),
          // const SizedBox(height: 20),
          // _buildDrawerItem(
          //   icon: Icons.settings_rounded,
          //   title: 'Settings',
          //   onTap: () => Navigator.pop(context),
          // ),
          // _buildDrawerItem(
          //   icon: Icons.help_rounded,
          //   title: 'Help & Support',
          //   onTap: () => Navigator.pop(context),
          // ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required Widget icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: icon,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.6),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
