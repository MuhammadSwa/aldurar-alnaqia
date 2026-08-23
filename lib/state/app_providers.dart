import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/audioPlayer/audio_player.dart';

/// Initialized in main() before runApp and injected via ProviderScope
/// overrides, because it requires an async [StorageService.init].
final storageProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageProvider must be overridden in main()');
});

/// App-wide audio playback service. Created lazily on first access.
final audioPlayerProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService(storage: ref.watch(storageProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Download manager service. Created lazily on first access.
final downloaderProvider = Provider<DownloaderService>((ref) {
  final service = DownloaderService(storage: ref.watch(storageProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Registry of scaffold keys so drawers can be closed globally before
/// switching bottom-nav branches.
class DrawerRegistry {
  final List<GlobalKey<ScaffoldState>> _scaffoldKeys = [];

  void registerScaffoldKey(GlobalKey<ScaffoldState> key) {
    if (!_scaffoldKeys.contains(key)) {
      _scaffoldKeys.add(key);
    }
  }

  void unregisterScaffoldKey(GlobalKey<ScaffoldState> key) {
    _scaffoldKeys.remove(key);
  }

  bool get hasOpenDrawer {
    for (final key in _scaffoldKeys) {
      if (key.currentState?.isDrawerOpen == true) {
        return true;
      }
    }
    return false;
  }

  void closeAllDrawers() {
    for (final key in _scaffoldKeys) {
      if (key.currentState?.isDrawerOpen == true) {
        Navigator.of(key.currentContext!).pop();
      }
    }
  }
}

final drawerRegistryProvider = Provider<DrawerRegistry>((ref) {
  return DrawerRegistry();
});

// ---------------------------------------------------------------------------
// Settings (persisted via SharedPreferences)
// ---------------------------------------------------------------------------

class FontSizeNotifier extends Notifier<double> {
  @override
  double build() => SharedPreferencesService.getFontSize();

  void change(double newSize) {
    SharedPreferencesService.setFontSize(newSize);
    state = newSize;
  }
}

final fontSizeProvider =
    NotifierProvider<FontSizeNotifier, double>(FontSizeNotifier.new);

class FontFamilyNotifier extends Notifier<String> {
  @override
  String build() => SharedPreferencesService.getQuranFontFamily();

  void change(String newFamily) {
    SharedPreferencesService.setQuranFontFamily(newFamily);
    state = newFamily;
  }
}

final fontFamilyProvider =
    NotifierProvider<FontFamilyNotifier, String>(FontFamilyNotifier.new);

class BookmarksNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => SharedPreferencesService.getBookmarks();

  bool isBookmarked(String bookmarkId) => state.contains(bookmarkId);

  /// Returns the previous bookmarked state (true if it was bookmarked).
  bool toggleBookmark(String bookmarkId) {
    final wasBookmarked = state.contains(bookmarkId);
    if (wasBookmarked) {
      SharedPreferencesService.removeBookmark(bookmarkId);
      state = [...state]..remove(bookmarkId);
    } else {
      SharedPreferencesService.addBookmark(bookmarkId);
      state = [...state, bookmarkId];
    }
    return wasBookmarked;
  }
}

final bookmarksProvider =
    NotifierProvider<BookmarksNotifier, List<String>>(BookmarksNotifier.new);

class HijriOffsetNotifier extends Notifier<int> {
  @override
  int build() => SharedPreferencesService.getHijriDayOffset();

  void set(int offset) {
    SharedPreferencesService.setHijriDayOffset(offset);
    state = offset;
  }
}

final hijriOffsetProvider =
    NotifierProvider<HijriOffsetNotifier, int>(HijriOffsetNotifier.new);
