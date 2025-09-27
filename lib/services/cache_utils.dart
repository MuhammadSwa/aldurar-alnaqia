import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CacheUtils {
  static Future<int> clearCache() async {
    final tempDir = await getTemporaryDirectory();
    int bytesFreed = 0;
    if (await tempDir.exists()) {
      bytesFreed = await _deleteDirContents(tempDir);
    }
    return bytesFreed;
  }

  static Future<int> _deleteDirContents(Directory dir) async {
    int bytes = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      try {
        if (entity is File) {
          bytes += await entity.length();
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
    return bytes;
  }
}
