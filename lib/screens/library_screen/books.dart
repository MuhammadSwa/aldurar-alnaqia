/// Static catalogue of library books: the single source of truth used by the
/// library list, the book viewer and the download manager.
///
/// [BookInfo.id] is an ASCII slug used for routes, storage filenames, saved
/// page keys and download ids. [fullTitle] is the complete display name
/// shown title-only (it wraps to two lines); [title] / [subtitle] are the
/// short forms used where space is tight (viewer app bar, manager rows).
class BookInfo {
  const BookInfo({
    required this.id,
    required this.fullTitle,
    required this.title,
    this.subtitle,
    required this.url,
  });

  final String id;
  final String fullTitle;
  final String title;
  final String? subtitle;
  final String url;
}

const books = <BookInfo>[
  BookInfo(
    id: 'dorar-awrad',
    fullTitle: 'الدرر النقية في أوراد الطريقة اليسرية الصديقية الشاذلية',
    title: 'الدرر النقية',
    subtitle: 'أوراد الطريقة اليسرية الصديقية الشاذلية',
    url: 'https://archive.org/download/dorar_app_book/dorar_awrad.pdf',
  ),
  BookInfo(
    id: 'anwar-galia',
    fullTitle: 'الأنوار الجلية في الجمع بين دلائل الخيرات والصلوات اليسرية',
    title: 'الأنوار الجلية',
    subtitle: 'الجمع بين دلائل الخيرات والصلوات اليسرية',
    url: 'https://archive.org/download/dorar_app_book/anwar_galia.pdf',
  ),
  BookInfo(
    id: 'hadra-yousria',
    fullTitle: 'الحضرة اليسرية الصديقية الشاذلية',
    title: 'الحضرة اليسرية',
    subtitle: 'الصديقية الشاذلية',
    url: 'https://archive.org/download/dorar_app_book/dorar_alhadra.pdf',
  ),
  BookInfo(
    id: 'irshad-bariya',
    fullTitle: 'إرشاد البرية إلى بعض معاني الحكم العطائية',
    title: 'إرشاد البرية',
    subtitle: 'إلى بعض معاني الحكم العطائية',
    url:
        'https://archive.org/download/dorar_app_book/irshad_albariyat_hukm_eatayiya.pdf',
  ),
  BookInfo(
    id: 'fotouhat-yousria',
    fullTitle: 'الفتوحات اليسرية في شرح عقائد الأمة المحمدية',
    title: 'الفتوحات اليسرية',
    subtitle: 'شرح عقائد الأمة المحمدية',
    url:
        'https://archive.org/download/dorar_app_book/alfutuhat_alyasriat_eaqayid_alumat_almuhamadia.pdf',
  ),
  BookInfo(
    id: 'sharh-salawat-awlia',
    fullTitle: 'شرح صلوات الأولياء',
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
