import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Foreground temp downloader for online book previews.
///
/// NOTE: this intentionally keeps using [HttpClient] and does NOT switch to
/// `background_downloader`. The temp preview is a throwaway cache file that
/// must be available synchronously as a [File] path for `PdfDocument.openFile`.
/// `background_downloader` targets persistent offline downloads (handled via
/// `downloaderProvider` in `_downloadForOffline`), needs native plugin setup
/// and delivers results via task callbacks — overkill and racy for a simple
/// open-and-preview flow with inline progress reporting.
class BookTempLoader {
  /// Temp cache file for [id]'s online preview.
  static Future<File> tempFile(String id) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/online_${id.hashCode}.pdf');
  }

  /// Downloads [url] to the temp dir, reporting progress via [onProgress].
  ///
  /// Returns the cached file when it already exists unless [fresh] is true.
  /// Writes to a `.part` file then atomically renames it. Timeouts apply to
  /// connect/headers only; slow bodies keep streaming. Throws [HttpException]
  /// on non-200 responses.
  static Future<File> downloadToTemp({
    required String url,
    required String id,
    required void Function(int received, int? total) onProgress,
    bool fresh = false,
  }) async {
    final file = await tempFile(id);

    if (!fresh && await file.exists() && await file.length() > 0) {
      return file;
    }

    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('فشل التحميل (${response.statusCode})');
      }

      final total =
          response.contentLength > 0 ? response.contentLength : null;
      final tmp = File('${file.path}.part');
      final sink = tmp.openWrite();
      var received = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, total);
        }
      } finally {
        await sink.close();
      }
      await tmp.rename(file.path);
      return file;
    } finally {
      client.close();
    }
  }

  static int? parsePage(String raw) => int.tryParse(raw.trim());
}
