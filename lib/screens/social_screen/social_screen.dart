import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
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
      required this.iconColor});
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
      title: 'قناة اليوتيوب',
      url: 'https://www.youtube.com/c/MohamadSameh',
      icon: SvgPicture.asset(
        'assets/icons/youtube-icon-svgrepo-com.svg',
        semanticsLabel: 'youtube_icon',
        width: 24,
        // colorFilter: ColorFilter.mode(Colors.red, BlendMode.srcIn),
      ),
      iconColor: Colors.transparent),

  _SocialSite(
    title: 'صفحة الانستجرام',
    url: 'http://www.instagram.com/DrYosryGabr',
    icon: SvgPicture.asset(
      'assets/icons/instagram-svgrepo-com.svg',
      semanticsLabel: 'instagram_icon',
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
  //
  _SocialSite(
    title: 'صفحة التيك توك',
    url: 'http://www.tiktok.com/@dryosrygabr',
    icon: const Icon(Icons.tiktok),
    iconColor: Colors.deepPurple,
  ),

  _SocialSite(
    title: 'حساب الساوند كلاود',
    url: 'https://soundcloud.com/dryosrygabr',
    icon: SvgPicture.asset(
      'assets/icons/soundcloud-svgrepo-com.svg',
      semanticsLabel: 'soundcloud_icon',
      width: 24,
    ),
    iconColor: Colors.transparent,
  ),

  _SocialSite(
    title: 'حساب التويتر 𝕏',
    url: 'http://www.twitter.com/DrYosryGabr',
    icon: SvgPicture.asset(
      'assets/icons/icons8-twitterx.svg',
      semanticsLabel: 'twitter_icon',
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      width: 29,
    ),
    iconColor: Colors.transparent,
  ),
  _SocialSite(
      title: 'مسجد الأشراف',
      url: 'https://maps.app.goo.gl/8Eog1x4g8nQqtKSc9',
      icon: const Icon(Icons.location_on),
      iconColor: Colors.green),
  _SocialSite(
    title: 'توصية ورجاء وأمر لجميع المتابعين',
    url: 'https://youtu.be/KbQnZN5x2-g',
    icon: SvgPicture.asset(
      'assets/icons/youtube-icon-svgrepo-com.svg',
      semanticsLabel: 'youtube_icon',
      width: 24,
    ),
    iconColor: Colors.transparent,
  ),
  _SocialSite(
    title: 'كيفية قراءة الأوراد',
    url: 'https://youtu.be/IyrWSL4jd00',
    icon: SvgPicture.asset(
      'assets/icons/youtube-icon-svgrepo-com.svg',
      semanticsLabel: 'youtube_icon',
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
                // constraints: BoxConstraints(
                //     maxWidth: ),
                width: MediaQuery.sizeOf(context).width * .8,
                child: Column(
                  // mainAxisAlignment: MainAxisAlignment.,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('الصفحات الرسمية لفضيلة أ.د. يسري جبر'),
                    const SizedBox(
                      height: 20,
                    ),
                    Image.asset(
                      'assets/imgs/social_png.png',
                    ),
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _sites.length,
                      itemBuilder: (context, i) {
                        final site = _sites[i];
                        return ListTile(
                          title: Text(site.title),
                          trailing: IconButton(
                            style: const ButtonStyle(
                                iconSize: WidgetStatePropertyAll(27)),
                            color: site.iconColor,
                            icon: site.icon,
                            onPressed: () {
                              launchUrl(Uri.parse(site.url));
                            },
                          ),
                        );
                      },
                    )
                  ],
                ),
              )),
            )));
  }
}
