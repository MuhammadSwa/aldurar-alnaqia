import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:aldurar_alnaqia/models/download_models.dart';

/// StorageService centralizes where we keep persistent files
/// (e.g., downloaded books and narrations) under the app's
/// Application Support directory, and ensures subfolders exist.
///
/// Download folders hold re-downloadable content, so they are excluded from
/// OS backups: `isExcludedFromBackup` on iOS (via the `app/storage` channel)
/// and `backup_rules.xml` on Android.
class StorageService {
  late final String supportDirPath;

  static const _backupChannel = MethodChannel('app/storage');

  Future<StorageService> init() async {
    final supportDir = await getApplicationSupportDirectory();
    supportDirPath = supportDir.path;
    // Ensure our sub-directories exist
    await Future.wait([
      _ensureDir(_typeDir(DownloadType.books)),
      _ensureDir(_typeDir(DownloadType.narrations)),
    ]);
    return this;
  }

  String _typeDir(DownloadType type) => '$supportDirPath/${type.directoryName}';

  Future<void> _ensureDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    // Re-applied every launch so pre-existing installs get excluded too.
    await _excludeFromBackup(path);
  }

  /// Best-effort iCloud backup exclusion (iOS only). Never throws: tests and
  /// unsupported hosts simply skip it.
  Future<void> _excludeFromBackup(String path) async {
    if (!Platform.isIOS) return;
    try {
      await _backupChannel.invokeMethod('excludeFromBackup', {'path': path});
    } catch (_) {
      // Exclusion is an optimization, not a requirement.
    }
  }

  /// Returns full path for a stored item
  String pathFor(DownloadType type, String id) {
    return '${_typeDir(type)}/$id.${type.extension}';
  }

  /// Ensures the directory for this type exists
  Future<void> ensureTypeDir(DownloadType type) => _ensureDir(_typeDir(type));

  /// Size of a stored item in bytes, or null when missing/unreadable.
  Future<int?> fileSizeBytes(DownloadType type, String id) async {
    try {
      final file = File(pathFor(type, id));
      if (!await file.exists()) return null;
      return file.length();
    } catch (_) {
      return null;
    }
  }

  Future<bool> exists(DownloadType type, String id) async {
    final file = File(pathFor(type, id));
    return file.exists();
  }
}
