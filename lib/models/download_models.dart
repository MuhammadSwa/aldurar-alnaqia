import 'package:aldurar_alnaqia/services/storage_service.dart' show StorageService;

/// Download domain models (type + item).
///
/// Lives in `models/` so low-level services (e.g. [StorageService]) don't
/// depend on UI screens — previously these lived in
/// `screens/download_manager_screen/download_controller.dart`, forcing a
/// service -> screen reverse dependency.
enum DownloadType { narrations, books }

extension DownloadTypeExtension on DownloadType {
  String get extension => this == DownloadType.narrations ? 'mp3' : 'pdf';
  String get directoryName => name;
}

class DownloadItem {

  const DownloadItem({
    required this.id,
    required this.title,
    required this.url,
    required this.type,
  });
  final String id;
  final String title;
  final String url;
  final DownloadType type;
}
