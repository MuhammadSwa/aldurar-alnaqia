import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/common/helpers/logger.dart';
// TODO: move to controllers folder

enum DownloadType { narrations, books }

extension DownloadTypeExtension on DownloadType {
  String get extension => this == DownloadType.narrations ? 'mp3' : 'pdf';
  String get directoryName => name;
}

class DownloadItem {
  final String id;
  final String title;
  final String url;
  final DownloadType type;

  const DownloadItem({
    required this.id,
    required this.title,
    required this.url,
    required this.type,
  });
}

class DownloaderController extends GetxController {
  // Download progress tracking
  final _downloadProgress = <String, ValueNotifier<double>>{}.obs;

  // File status cache to avoid repeated file system checks
  final _fileStatusCache = <String, bool>{}.obs;

  // In-flight status checks to coalesce queries
  final Map<String, Future<bool>> _statusFutures = {};

  // Storage service (resolved lazily to avoid test coupling)
  late final StorageService _storage;

  // Getters
  Map<String, ValueNotifier<double>> get downloadProgress => _downloadProgress;
  Map<String, bool> get fileStatusCache => _fileStatusCache;

  @override
  void onInit() {
    super.onInit();
  _storage = Get.put(StorageService(), permanent: true);
  // If not initialized yet, kick off init but don't block UI
  _storage.init();
    _initializeDownloader();
  _initializeFileStatusCache();
  }

  void _initializeDownloader() {
    FileDownloader().trackTasks();
    FileDownloader().updates.listen(_handleDownloadUpdate);
  }

  void _handleDownloadUpdate(TaskUpdate update) {
    switch (update) {
      case TaskStatusUpdate():
        _handleStatusUpdate(update);
        break;
      case TaskProgressUpdate():
        _handleProgressUpdate(update);
        break;
    }
  }

  void _handleStatusUpdate(TaskStatusUpdate update) {
    final taskId = update.task.taskId;

    if (update.status == TaskStatus.complete) {
      _downloadProgress.remove(taskId);
      _fileStatusCache[taskId] = true;
    } else if (update.status == TaskStatus.canceled ||
        update.status == TaskStatus.failed) {
      _downloadProgress.remove(taskId);
      _fileStatusCache[taskId] = false;
    }
  }

  void _handleProgressUpdate(TaskProgressUpdate update) {
    _downloadProgress[update.task.taskId] = ValueNotifier(update.progress);
  }

  Future<void> _initializeFileStatusCache() async {
    // Ensure folders exist
    await _storage.ensureTypeDir(DownloadType.books);
    await _storage.ensureTypeDir(DownloadType.narrations);
  }

  String _getFilePath(String id, DownloadType type) => _storage.pathFor(type, id);

  Future<void> startDownload(DownloadItem item) async {
    if (isDownloading(item.id)) return;

    final task = DownloadTask(
      taskId: item.id,
      filename: '${item.id}.${item.type.extension}',
      url: item.url,
      directory: item.type.directoryName,
      baseDirectory: BaseDirectory.applicationSupport,
      allowPause: true,
      updates: Updates.statusAndProgress,
    );

    await FileDownloader().enqueue(task);
  }

  Future<void> cancelDownload(String id) async {
    await FileDownloader().cancelTaskWithId(id);
    _downloadProgress.remove(id);
  }

  Future<void> deleteFile(String id, DownloadType type) async {
    try {
      final filePath = _getFilePath(id, type);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }

      _fileStatusCache[id] = false;
    } catch (e, st) {
      logError('Error deleting file', e, st);
    }
  }

  Future<bool> isFileDownloaded(String id, DownloadType type) async {
    // Check cache first
    if (_fileStatusCache.containsKey(id)) {
      return _fileStatusCache[id]!;
    }

    // Check file system
    try {
  final exists = await _storage.exists(type, id);

      // Update cache
      _fileStatusCache[id] = exists;
      return exists;
    } catch (e, st) {
      logError('Error checking file', e, st);
      return false;
    }
  }

  /// Ensure we know the status of a file by triggering a single in-flight check
  /// if it's not already cached. Safe to call multiple times.
  Future<bool> ensureKnown(String id, DownloadType type) {
    if (_fileStatusCache.containsKey(id)) {
      return Future.value(_fileStatusCache[id]!);
    }
  return _statusFutures[id] ??= isFileDownloaded(id, type).whenComplete(() {
      _statusFutures.remove(id);
    });
  }

  bool isDownloading(String id) {
    return _downloadProgress.containsKey(id);
  }

  double? getDownloadProgress(String id) {
    return _downloadProgress[id]?.value;
  }

  // Batch operations
  Future<void> cancelAllDownloads() async {
    final downloadIds = _downloadProgress.keys.toList();
    for (final id in downloadIds) {
      await cancelDownload(id);
    }
  }

  Future<void> refreshFileStatus(String id, DownloadType type) async {
    _fileStatusCache.remove(id);
    await isFileDownloaded(id, type);
  }
}
