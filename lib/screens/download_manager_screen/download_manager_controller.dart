// lib/screens/download_manager_screen/download_manager_controller.dart
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/screens/library_screen/library_screen.dart'
    show booksTitles;
import 'download_controller.dart';

// NOTE: pure data helpers for the download manager screen, not the downloads
// themselves (those live in [DownloaderService]).

class DownloadManagerData {
  /// Groups narrations by collection for the audio tab.
  static Map<String, List<DownloadItem>> loadAudioSections() {
    final loadedAudio = <String, List<DownloadItem>>{};
    for (var entry in azkarWithNarrations.entries) {
      final items = entry.value
          .where((zikr) => zikr.url != null && zikr.url!.isNotEmpty)
          .map((zikr) => DownloadItem(
                id: zikr.title,
                title: zikr.title,
                url: zikr.url!,
                type: DownloadType.narrations,
              ))
          .toList();
      if (items.isNotEmpty) {
        loadedAudio[entry.key] = items;
      }
    }
    return loadedAudio;
  }

  static List<DownloadItem> loadBookItems() {
    return booksTitles.entries.map((entry) {
      return DownloadItem(
        id: entry.key,
        title: entry.key,
        url: entry.value,
        type: DownloadType.books,
      );
    }).toList();
  }
}
