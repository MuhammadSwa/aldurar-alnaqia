import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';

import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/common/helpers/logger.dart';

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

/// Framework-agnostic download orchestration service.
///
/// - File status changes are surfaced through [statusRevision] (bump the
///   listener count) so widgets can rebuild cheaply.
/// - Per-task progress uses one [ValueNotifier] per task, updated in place
///   (no per-tick allocations).
class DownloaderService {
  DownloaderService({required StorageService storage}) : _storage = storage {
    _initializeDownloader();
    _initializeFileStatusCache();
  }

  final StorageService _storage;

  // Download progress tracking (one stable notifier per task)
  final Map<String, ValueNotifier<double>> _downloadProgress = {};

  // File status cache to avoid repeated file system checks.
  // Mutations are followed by a [statusRevision] bump.
  final Map<String, bool> _fileStatusCache = {};

  /// Increments on every file-status change; widgets listen to rebuild.
  final ValueNotifier<int> statusRevision = ValueNotifier<int>(0);

  // In-flight status checks to coalesce queries
  final Map<String, Future<bool>> _statusFutures = {};

  StreamSubscription<TaskUpdate>? _updatesSub;

  void _bumpStatusRevision() => statusRevision.value++;

  void _initializeDownloader() {
    try {
      FileDownloader().trackTasks();
      _updatesSub = FileDownloader().updates.listen(_handleDownloadUpdate);
    } catch (e, st) {
      logError('Failed to initialize background downloader', e, st);
    }
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
    var changed = false;

    if (update.status == TaskStatus.complete) {
      _downloadProgress.remove(taskId)?.dispose();
      _fileStatusCache[taskId] = true;
      changed = true;
    } else if (update.status == TaskStatus.canceled ||
        update.status == TaskStatus.failed ||
        update.status == TaskStatus.notFound) {
      _downloadProgress.remove(taskId)?.dispose();
      _fileStatusCache[taskId] = false;
      changed = true;
    }

    if (changed) _bumpStatusRevision();
  }

  void _handleProgressUpdate(TaskProgressUpdate update) {
    // Reuse a single notifier per task instead of allocating per tick.
    (_downloadProgress[update.task.taskId] ??= ValueNotifier<double>(0))
        .value = update.progress;
  }

  Future<void> _initializeFileStatusCache() async {
    // Ensure folders exist
    await _storage.ensureTypeDir(DownloadType.books);
    await _storage.ensureTypeDir(DownloadType.narrations);
  }

  String _getFilePath(String id, DownloadType type) => _storage.pathFor(type, id);

  bool isDownloading(String id) => _downloadProgress.containsKey(id);

  ValueNotifier<double>? progressNotifierFor(String id) =>
      _downloadProgress[id];

  double? getDownloadProgress(String id) => _downloadProgress[id]?.value;

  bool? cachedStatus(String id) => _fileStatusCache[id];

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

    try {
      await FileDownloader().enqueue(task);
    } catch (e, st) {
      logError('Failed to enqueue download for "${item.id}"', e, st);
    }
  }

  Future<void> cancelDownload(String id) async {
    try {
      await FileDownloader().cancelTaskWithId(id);
    } catch (e, st) {
      logError('Failed to cancel download "$id"', e, st);
    }
    _downloadProgress.remove(id)?.dispose();
    _bumpStatusRevision();
  }

  Future<void> deleteFile(String id, DownloadType type) async {
    try {
      final filePath = _getFilePath(id, type);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }

      _fileStatusCache[id] = false;
      _bumpStatusRevision();
    } catch (e, st) {
      logError('Error deleting file', e, st);
    }
  }

  Future<bool> isFileDownloaded(String id, DownloadType type) async {
    // Check cache first
    final cached = _fileStatusCache[id];
    if (cached != null) return cached;

    // Check file system
    try {
      final exists = await _storage.exists(type, id);

      // Update cache
      _fileStatusCache[id] = exists;
      _bumpStatusRevision();
      return exists;
    } catch (e, st) {
      logError('Error checking file', e, st);
      return false;
    }
  }

  /// Ensure we know the status of a file by triggering a single in-flight check
  /// if it's not already cached. Safe to call multiple times.
  Future<bool> ensureKnown(String id, DownloadType type) {
    final cached = _fileStatusCache[id];
    if (cached != null) return Future.value(cached);
    return _statusFutures[id] ??= isFileDownloaded(id, type).whenComplete(() {
      _statusFutures.remove(id);
    });
  }

  // Batch operations
  Future<void> cancelAllDownloads() async {
    try {
      // Cancels ALL tracked tasks, including ones restored after restart —
      // not just those in this session's progress map.
      await FileDownloader().cancelAll();
    } catch (e, st) {
      logError('Failed to cancel all downloads', e, st);
    }
    for (final notifier in _downloadProgress.values) {
      notifier.dispose();
    }
    _downloadProgress.clear();
    _bumpStatusRevision();
  }

  Future<void> refreshFileStatus(String id, DownloadType type) async {
    _fileStatusCache.remove(id);
    _bumpStatusRevision();
    await isFileDownloaded(id, type);
  }

  void dispose() {
    _updatesSub?.cancel();
    for (final notifier in _downloadProgress.values) {
      notifier.dispose();
    }
    _downloadProgress.clear();
    statusRevision.dispose();
  }
}
