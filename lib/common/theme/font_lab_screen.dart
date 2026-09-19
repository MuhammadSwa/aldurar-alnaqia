import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// TEMPORARY typography lab: Arabic Google Fonts rendered on real heading +
/// body samples for comparison. Fonts load from the network on first use.
/// Delete after choices are made (then bundle the winners as assets).
class FontLabScreen extends StatelessWidget {
  const FontLabScreen({super.key});

  static const _families = <(String, String)>[
    ('Noto Naskh Arabic', 'الحالي'),
    ('Scheherazade New', 'نسخي دقيق'),
    ('Amiri', 'نسخي تقليدي'),
    ('Markazi Text', 'نسخي حديث'),
    ('Lateef', 'نسخي واسع'),
    ('Harmattan', 'واضح للقراءة'),
    ('Katibeh', 'عنواني ثقيل'),
    ('El Messiri', 'أنيق متوازن'),
    ('Noto Kufi Arabic', 'كوفي هندسي'),
    ('Reem Kufi', 'كوفي معاصر'),
    ('Changa', 'عريض م condensed'),
    ('Cairo', 'عصري شامل'),
    ('Almarai', 'عملي نظيف'),
    ('Tajawal', 'خفيف عصري'),
    ('Readex Pro', 'مقروئية عالية'),
    //
    ('IBM Plex Sans Arabic', 'تقني رصين'),

    ('Mada', 'بسيط مريح'), //
    ('Aref Ruqaa', 'رقعة للعناوين'), //
    ('Rakkas', 'زخرفي للعناوين'), //
  ];

  static const _headingSample = 'مواقيت الصلاة والأوراد';
  static const _bodySample =
      'اللهم صل وسلم وبارك على سيدنا محمد وعلى آله وصحبه أجمعين';
  static const _digitsSample = '٠١٢٣٤٥٦٧٨٩ • 0123456789';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخطوط — مؤقت')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _families.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final (family, _) = _families[i];
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          family,
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _headingSample,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.getFont(
                        family,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bodySample,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.getFont(
                        family,
                        fontSize: 18,
                        height: 1.9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _digitsSample,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.getFont(family, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
