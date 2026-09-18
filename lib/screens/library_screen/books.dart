/// Static catalogue of library books: the single source of truth used by the
/// library list, the book viewer and the download manager.
///
/// [BookInfo.id] is an ASCII slug used for routes, storage filenames, saved
/// page keys and download ids. [title] / [subtitle] are display-only.
class BookInfo {
  const BookInfo({
    required this.id,
    required this.title,
    this.subtitle,
    required this.url,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String url;
}

const books = <BookInfo>[
  BookInfo(
    id: 'dorar-awrad',
    title: 'الدرر النقية',
    subtitle: 'أوراد الطريقة اليسرية الصديقية الشاذلية',
    url: 'https://archive.org/download/dorar_app_book/dorar_awrad.pdf',
  ),
  BookInfo(
    id: 'anwar-galia',
    title: 'الأنوار الجلية',
    subtitle: 'الجمع بين دلائل الخيرات والصلوات اليسرية',
    url: 'https://archive.org/download/dorar_app_book/anwar_galia.pdf',
  ),
  BookInfo(
    id: 'hadra-yousria',
    title: 'الحضرة اليسرية',
    subtitle: 'الصديقية الشاذلية',
    url: 'https://archive.org/download/dorar_app_book/dorar_alhadra.pdf',
  ),
  BookInfo(
    id: 'irshad-bariya',
    title: 'إرشاد البرية',
    subtitle: 'إلى بعض معاني الحكم العطائية',
    url:
        'https://archive.org/download/dorar_app_book/irshad_albariyat_hukm_eatayiya.pdf',
  ),
  BookInfo(
    id: 'fotouhat-yousria',
    title: 'الفتوحات اليسرية',
    subtitle: 'شرح عقائد الأمة المحمدية',
    url:
        'https://archive.org/download/dorar_app_book/alfutuhat_alyasriat_eaqayid_alumat_almuhamadia.pdf',
  ),
  BookInfo(
    id: 'sharh-salawat-awlia',
    title: 'شرح صلوات الأولياء',
    url:
        'https://archive.org/download/dorar_app_book/sharh_salawat_alawlia_ealaa_khatam_alanbia.pdf',
  ),
];

/// Looks a book up by its [BookInfo.id]. Returns null for unknown ids.
BookInfo? bookById(String id) {
  for (final b in books) {
    if (b.id == id) return b;
  }
  return null;
}
