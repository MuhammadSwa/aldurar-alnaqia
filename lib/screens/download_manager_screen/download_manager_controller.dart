// lib/screens/download_manager_screen/download_manager_controller.dart
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/screens/library_screen/books.dart';

// NOTE: pure data helpers for the download manager screen, not the downloads
// themselves (those live in [DownloaderService]).

class DownloadManagerData {
  /// Groups narrations by section for the audio tab. Sections derive from
  /// [audioSections]; only items with audio are listed.
  static Map<String, List<DownloadItem>> loadAudioSections() {
    final loadedAudio = <String, List<DownloadItem>>{};
    for (final section in audioSections) {
      final items = section.withAudio
          .map((zikr) => DownloadItem(
                id: zikr.id,
                title: zikr.title,
                url: zikr.url!,
                type: DownloadType.narrations,
              ),)
          .toList();
      if (items.isNotEmpty) {
        loadedAudio[section.title] = items;
      }
    }
    return loadedAudio;
  }

  static List<DownloadItem> loadBookItems() {
    // id is the slug (storage / prefs key on it);
    // title is the full display name.
    return books.map((book) {
      return DownloadItem(
        id: book.id,
        title: book.fullTitle,
        url: book.url,
        type: DownloadType.books,
      );
    }).toList();
  }
}
