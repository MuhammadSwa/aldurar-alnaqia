import 'dart:async';

import 'package:aldurar_alnaqia/common/theme/font_lab_screen.dart';
import 'package:aldurar_alnaqia/common/theme/theme_preview_screen.dart';
import 'package:aldurar_alnaqia/common/theme/tile_separator_lab_screen.dart';
import 'package:aldurar_alnaqia/common/widgets/settings_card.dart';
import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/router/nav_helpers.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/file_action_setting_widget.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/font_settings_widget.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/theme_mode_setting_widget.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/yousria_beginning_day_dropdown_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      elevation: 0,
      semanticLabel: 'القائمة الجانبية',
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            const ThemeModeSettingWidget(
              cardStyle: SettingsCardStyle.outlined,
            ),
            const YousriaBeginningDayDropDown(
              cardStyle: SettingsCardStyle.outlined,
            ),
            const FileActionSettingWidget(
              cardStyle: SettingsCardStyle.outlined,
            ),
            const FontSizeSettingsWidget(
              cardStyle: SettingsCardStyle.outlined,
            ),

            _buildDrawerItem(
              context: context,
              icon: Icon(
                Icons.cloud_download_rounded,
                color: colorScheme.onSecondaryContainer,
                size: 20,
              ),
              title: 'إدارة التحميلات',
              onTap: () {
                Navigator.pop(context);
                AppNav.goToDownloadManager(context, 0);
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Divider(height: 1),
            ),
            _buildDrawerItem(
              context: context,
              icon: Icon(
                Icons.link,
                color: colorScheme.onSecondaryContainer,
                size: 20,
              ),
              title: 'الصفحات الرسمية',
              onTap: () {
                Navigator.pop(context);
                context.push(RoutePaths.social);
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Image.asset(
                'assets/icons/youtube-icon.png',
                semanticLabel: 'youtube_icon',
                width: 24,
              ),
              title: 'كيفية قراءة الأوراد',
              onTap: () {
                Navigator.pop(context);
                unawaited(
                  launchUrl(
                    Uri.parse('https://youtu.be/IyrWSL4jd00'),
                    mode: LaunchMode.externalApplication,
                  ),
                );
              },
            ),
            _buildDrawerItem(
              context: context,
              icon: Image.asset(
                'assets/icons/youtube-icon.png',
                semanticLabel: 'youtube_icon',
                width: 24,
              ),
              title: 'أسئلة المتابعين',
              onTap: () {
                Navigator.pop(context);
                unawaited(
                  launchUrl(
                    Uri.parse(
                      'https://www.youtube.com/playlist?list=PLEkQk5xrP-tkGXuZ9atE3k_7it12rUPTs',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                );
              },
            ),
            // // TEMPORARY: theme preview entry. Preview-only, safe to keep/remove.
            // _buildDrawerItem(
            //   context: context,
            //   icon: Icon(
            //     Icons.palette_outlined,
            //     color: colorScheme.onSecondaryContainer,
            //     size: 20,
            //   ),
            //   title: 'تجربة الألوان (مؤقت)',
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.of(context).push(
            //       MaterialPageRoute(
            //         builder: (_) => const ThemePreviewScreen(),
            //       ),
            //     );
            //   },
            // ),
            // // TEMPORARY: font-lab entry. Remove after choices are made.
            // _buildDrawerItem(
            //   context: context,
            //   icon: Icon(
            //     Icons.text_fields_outlined,
            //     color: colorScheme.onSecondaryContainer,
            //     size: 20,
            //   ),
            //   title: 'معاينة الخطوط (مؤقت)',
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.of(context).push(
            //       MaterialPageRoute(
            //         builder: (_) => const FontLabScreen(),
            //       ),
            //     );
            //   },
            // ),
            // // TEMPORARY: tile-separator lab. Remove after a choice is made.
            // _buildDrawerItem(
            //   context: context,
            //   icon: Icon(
            //     Icons.view_agenda_outlined,
            //     color: colorScheme.onSecondaryContainer,
            //     size: 20,
            //   ),
            //   title: 'فواصل البلاطات (مؤقت)',
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.of(context).push(
            //       MaterialPageRoute(
            //         builder: (_) => const TileSeparatorLabScreen(),
            //       ),
            //     );
            //   },
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required Widget icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SettingsCard(
      style: SettingsCardStyle.outlined,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: colorScheme.onSurface.withValues(alpha: 0.1),
          highlightColor: colorScheme.onSurface.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: icon,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
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
