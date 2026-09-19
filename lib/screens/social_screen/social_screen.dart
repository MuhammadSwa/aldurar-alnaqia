import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class _SocialSite {
  final String title;
  final String url;
  final Widget icon;
  final Color iconColor;

  _SocialSite(
      {required this.title,
      required this.url,
      required this.icon,
      required this.iconColor,});
}

final _sites = <_SocialSite>[
  _SocialSite(
    title: 'الصفحة الرسمية لفضيلة أ.د. يسري جبر',
    url: 'https://www.facebook.com/dr.yosrygabr/',
    icon: const Icon(Icons.facebook),
    iconColor: Colors.blue,
  ),

  _SocialSite(
    title: 'صفحة أوراد الطريقة اليسرية الصديقية',
    url: 'https://www.facebook.com/Awrad.Dryosry',
    icon: const Icon(Icons.facebook),
    iconColor: Colors.blue,
  ),
  _SocialSite(
    title: 'المجموعة الرسمية لنشر دروس وأخبار فضيلة أ.د. يسري جبر',
    url: 'https://www.facebook.com/groups/245819711389',
    icon: const Icon(Icons.facebook),
    iconColor: Colors.blue,
  ),

  _SocialSite(
    title: 'Dr. Yosry Gabr in English',
    url:
        'https://www.facebook.com/people/Dr-Yosry-Gabr-in-English/61574856976137',
    icon: const Icon(Icons.facebook),
    iconColor: Colors.blue,
  ),

  _SocialSite(
      title: 'قناة اليوتيوب',
      url: 'https://www.youtube.com/c/MohamadSameh',
      icon: Image.asset(
        'assets/icons/youtube-icon.png',
        semanticLabel: 'youtube_icon',
        width: 24,
      ),
      iconColor: Colors.transparent,),

  _SocialSite(
      title: 'دروس د.يسري جبر',
      url: 'https://youtube.com/@dryosrylectures?si=hzAsCiFuwVLpvTEb',
      icon: Image.asset(
        'assets/icons/youtube-icon.png',
        semanticLabel: 'youtube_icon',
        width: 24,
      ),
      iconColor: Colors.transparent,),

  _SocialSite(
    title: 'حساب الساوند كلاود',
    url: 'https://soundcloud.com/dryosrygabr',
    icon: Image.asset(
      'assets/icons/soundcloud-icon.png',
      semanticLabel: 'soundcloud_icon',
      width: 24,
    ),
    iconColor: Colors.transparent,
  ),

  //
  _SocialSite(
    title: 'قناة التليجرام',
    url: 'https://t.me/DrYosryGabr',
    icon: const Icon(Icons.telegram),
    iconColor: Colors.blue,
  ),

  _SocialSite(
    title: 'صفحة الانستجرام',
    url: 'http://www.instagram.com/DrYosryGabr',
    icon: Image.asset(
      'assets/icons/instagram-icon.png',
      semanticLabel: 'instagram_icon',
      width: 24,
    ),
    iconColor: Colors.transparent,
  ),

  _SocialSite(
    title: 'Dr. Yosry Gabr in English',
    url: 'https://www.instagram.com/dryosrygabr_en/',
    icon: Image.asset(
      'assets/icons/instagram-icon.png',
      semanticLabel: 'instagram_icon',
      width: 24,
    ),
    iconColor: Colors.transparent,
  ),

  //
  _SocialSite(
    title: 'صفحة التيك توك',
    url: 'http://www.tiktok.com/@dryosrygabr',
    icon: const Icon(Icons.tiktok),
    iconColor: Colors.deepPurple,
  ),

  _SocialSite(
    title: 'حساب التويتر 𝕏',
    url: 'http://www.twitter.com/DrYosryGabr',
    icon: Builder(
      builder: (context) {
        // Adapts to light/dark mode for contrast (was hardcoded white,
        // invisible on light background).
        final color = Theme.of(context).colorScheme.onSurface;
        return Image.asset(
          'assets/icons/twitterx-icon.png',
          semanticLabel: 'twitter_icon',
          color: color,
          colorBlendMode: BlendMode.srcIn,
          width: 29,
        );
      },
    ),
    iconColor: Colors.transparent,
  ),
  _SocialSite(
      title: 'مسجد الأشراف',
      url: 'https://maps.app.goo.gl/8Eog1x4g8nQqtKSc9',
      icon: const Icon(Icons.location_on),
      iconColor: Colors.green,),
  _SocialSite(
    title: 'توصية ورجاء وأمر لجميع المتابعين',
    url: 'https://youtu.be/KbQnZN5x2-g',
    icon: Image.asset(
      'assets/icons/youtube-icon.png',
      semanticLabel: 'youtube_icon',
      width: 24,
    ),
    iconColor: Colors.transparent,
  ),
  _SocialSite(
    title: 'كيفية قراءة الأوراد',
    url: 'https://youtu.be/IyrWSL4jd00',
    icon: Image.asset(
      'assets/icons/youtube-icon.png',
      semanticLabel: 'youtube_icon',
      width: 24,
    ),
    iconColor: Colors.transparent,
  ),
];

class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: put in consts
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            appBar: AppBar(
              title: const Text('الصفحات الرسمية'),
            ),
            body: SingleChildScrollView(
              child: Center(
                  child: SizedBox(
                width: MediaQuery.sizeOf(context).width * .8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                      child: Text(
                        'الصفحات الرسمية لفضيلة أ.د. يسري جبر',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Image.asset(
                      'assets/imgs/social_webp.webp',
                    ),
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _sites.length,
                      itemBuilder: (context, i) {
                        final site = _sites[i];
                        void openSite() {
                          unawaited(launchUrl(
                            Uri.parse(site.url),
                            mode: LaunchMode.externalApplication,
                          ),);
                        }

                        return ListTile(
                          onTap: openSite,
                          title: Text(site.title),
                          trailing: IconButton(
                            style: const ButtonStyle(
                                iconSize: WidgetStatePropertyAll(27),),
                            color: site.iconColor,
                            icon: site.icon,
                            onPressed: openSite,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),),
            ),),);
  }
}
