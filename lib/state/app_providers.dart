import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';

/// Initialized in main() before runApp and injected via ProviderScope
/// overrides, because it requires an async [StorageService.init].
final storageProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageProvider must be overridden in main()');
});

/// Download manager service. Created lazily on first access.
final downloaderProvider = Provider<DownloaderService>((ref) {
  final service = DownloaderService(storage: ref.watch(storageProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Key of the single [Scaffold] in [MainWrapper] that owns the app drawer
/// and the bottom [NavigationBar].
///
/// Branch screens open it via `ref.read(rootScaffoldKeyProvider)` instead of
/// owning per-screen keys — previously each branch registered its own key in
/// a `DrawerRegistry` so the bottom nav could close drawers before `goBranch`
/// (with a 300ms delay). One owner removes the registry and the delay.
final rootScaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>((ref) {
  return GlobalKey<ScaffoldState>(debugLabel: 'rootDrawer');
});

// ---------------------------------------------------------------------------
// Settings (persisted via SharedPreferences)
// ---------------------------------------------------------------------------

class FontSizeNotifier extends Notifier<double> {
  @override
  double build() => SharedPreferencesService.getFontSize();

  /// Live preview while dragging (no disk write).
  void preview(double newSize) {
    state = newSize;
  }

  /// Persisted change (slider release / dialog close).
  void change(double newSize) {
    SharedPreferencesService.setFontSize(newSize);
    state = newSize;
  }
}

final fontSizeProvider =
    NotifierProvider<FontSizeNotifier, double>(FontSizeNotifier.new);

class BookmarksNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => SharedPreferencesService.getBookmarks();

  bool isBookmarked(String bookmarkId) => state.contains(bookmarkId);

  /// Returns the previous bookmarked state (true if it was bookmarked).
  bool toggleBookmark(String bookmarkId) {
    final wasBookmarked = state.contains(bookmarkId);
    if (wasBookmarked) {
      SharedPreferencesService.removeBookmark(bookmarkId);
      state = state.where((e) => e != bookmarkId).toList();
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

class YousriaBeginningNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => SharedPreferencesService.getYousriaBeginning();

  static DateTime midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 0 = today, 1 = yesterday, ... Clamped to the 6-day cycle.
  int relativeDay({DateTime? now}) {
    final todayMidnight = midnight(now ?? DateTime.now());
    final storedMidnight = midnight(state);
    return todayMidnight.difference(storedMidnight).inDays.clamp(0, 5);
  }

  Future<void> setBeginning(DateTime date) async {
    SharedPreferencesService.setYousriaBeginning(date);
    state = midnight(date);
  }

  Future<void> setRelativeDay(int relativeDayNum) async {
    final now = DateTime.now();
    await setBeginning(now.subtract(Duration(days: relativeDayNum)));
  }
}

final yousriaBeginningProvider =
    NotifierProvider<YousriaBeginningNotifier, DateTime>(
  YousriaBeginningNotifier.new,
);

/// What should happen when the user opens a file (audio or book) that
/// is not downloaded yet.
enum FileOpenAction {
  /// Show the open/download dialog every time.
  ask,

  /// Always open directly (stream audio / open book) without asking.
  open,

  /// Always start the download without asking.
  download;

  static FileOpenAction fromString(String? value) {
    return switch (value) {
      // 'stream' is the legacy audio value for the same behavior.
      'open' || 'stream' => FileOpenAction.open,
      'download' => FileOpenAction.download,
      _ => FileOpenAction.ask,
    };
  }

  String toStorageString() {
    return switch (this) {
      FileOpenAction.ask => 'ask',
      FileOpenAction.open => 'open',
      FileOpenAction.download => 'download',
    };
  }
}

class FileOpenActionNotifier extends Notifier<FileOpenAction> {
  @override
  FileOpenAction build() =>
      FileOpenAction.fromString(SharedPreferencesService.getFileOpenAction());

  Future<void> set(FileOpenAction action) async {
    await SharedPreferencesService.setFileOpenAction(
      action.toStorageString(),
    );
    state = action;
  }
}

final fileOpenActionProvider =
    NotifierProvider<FileOpenActionNotifier, FileOpenAction>(
  FileOpenActionNotifier.new,
);

// ---------------------------------------------------------------------------
// Theme mode (persisted via SharedPreferences; replaces `adaptive_theme`)
// ---------------------------------------------------------------------------

/// The app's appearance choice. This is the single source of truth consumed
/// by `MaterialApp.themeMode` in main.dart.
///
/// Stored as `'light' | 'dark' | 'system'` (see
/// `SharedPreferencesService.getThemeMode`), defaulting to [ThemeMode.system]
/// so fresh installs follow the OS.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      ThemeModeStorage.fromString(SharedPreferencesService.getThemeMode());

  /// Persist and apply [mode] (used by the appearance dropdown).
  Future<void> set(ThemeMode mode) async {
    await SharedPreferencesService.setThemeMode(mode.toStorageString());
    state = mode;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// String mapping for [ThemeMode] persistence. Kept here (next to the
/// provider) so `SharedPreferencesService` stays independent of Flutter
/// material. Mirrors the `FileOpenAction.fromString/toStorageString`
/// convention used above.
extension ThemeModeStorage on ThemeMode {
  static ThemeMode fromString(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  String toStorageString() {
    return switch (this) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
