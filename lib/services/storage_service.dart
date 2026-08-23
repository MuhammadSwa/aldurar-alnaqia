import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../screens/download_manager_screen/download_controller.dart';

/// StorageService centralizes where we keep persistent files
/// (e.g., downloaded books and narrations) under the app's
/// Application Support directory, and ensures subfolders exist.
class StorageService {
  late final String supportDirPath;

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
  }

  /// Returns full path for a stored item
  String pathFor(DownloadType type, String id) {
    return '${_typeDir(type)}/$id.${type.extension}';
  }

  /// Ensures the directory for this type exists
  Future<void> ensureTypeDir(DownloadType type) => _ensureDir(_typeDir(type));

  Future<bool> exists(DownloadType type, String id) async {
    final file = File(pathFor(type, id));
    return file.exists();
  }
}
