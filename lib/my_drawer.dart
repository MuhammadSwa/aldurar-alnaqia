import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/router/nav_helpers.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/file_action_setting_widget.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/font_settings_widget.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/theme_mode_setting_widget.dart';
import 'package:aldurar_alnaqia/screens/settings_screen/yousria_beginning_day_dropdown_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
class MyDrawer extends ConsumerWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Drawer(
        elevation: 0,
        semanticLabel: 'القائمة الجانبية',
        backgroundColor: colorScheme.surface,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              const ThemeModeSettingWidget(),
              const YousriaBeginningDayDropDown(),
              const FileActionSettingWidget(),
              const FontSizeSettingsWidget(),
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
                  }),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  }),
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
                    launchUrl(Uri.parse('https://youtu.be/IyrWSL4jd00'));
                  }),

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
                    launchUrl(Uri.parse(
                        'https://www.youtube.com/playlist?list=PLEkQk5xrP-tkGXuZ9atE3k_7it12rUPTs'));
                  }),
            ],
          ),
        ));
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required Widget icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
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
