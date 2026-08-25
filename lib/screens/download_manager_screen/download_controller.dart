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

  // Completed/canceled notifiers kept alive until service disposal, because
  // mounted widgets may still listen to them (see [_retireProgressNotifier]).
  final List<ValueNotifier<double>> _retiredProgressNotifiers = [];

  // File status cache to avoid repeated file system checks.
  // Mutations are followed by a [statusRevision] bump.
  // Keys are namespaced by type ('books/<id>' / 'narrations/<id>') so a book
  // and a narration sharing an id never corrupt each other's status.
  final Map<String, bool> _fileStatusCache = {};

  // In-flight status checks (same keying as [_fileStatusCache]).
  final Map<String, Future<bool>> _statusFutures = {};

  static String _statusKey(String id, DownloadType type) =>
      '${type.name}/$id';

  static DownloadType? _typeFromDirectoryName(String? directory) {
    for (final type in DownloadType.values) {
      if (type.directoryName == directory) return type;
    }
    return null;
  }

  /// Increments on every file-status change; widgets listen to rebuild.
  final ValueNotifier<int> statusRevision = ValueNotifier<int>(0);

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
    final type = _typeFromDirectoryName(update.task.directory);
    var changed = false;

    switch (update.status) {
      case TaskStatus.complete:
        _retireProgressNotifier(taskId);
        if (type != null) _fileStatusCache[_statusKey(taskId, type)] = true;
        changed = true;
        break;
      case TaskStatus.canceled:
      case TaskStatus.failed:
      case TaskStatus.notFound:
        _retireProgressNotifier(taskId);
        if (type != null) _fileStatusCache[_statusKey(taskId, type)] = false;
        changed = true;
        break;
      case TaskStatus.enqueued:
      case TaskStatus.running:
      case TaskStatus.paused:
        // A task became active: make sure the UI switches to the
        // progress state (GetX relied on its observable map for this).
        if (!_downloadProgress.containsKey(taskId)) {
          _downloadProgress[taskId] = ValueNotifier<double>(0);
          changed = true;
        }
        break;
      default:
        break;
    }

    if (changed) _bumpStatusRevision();
  }

  void _handleProgressUpdate(TaskProgressUpdate update) {
    final taskId = update.task.taskId;
    final isNew = !_downloadProgress.containsKey(taskId);
    // Reuse a single notifier per task instead of allocating per tick.
    (_downloadProgress[taskId] ??= ValueNotifier<double>(0)).value =
        update.progress;
    // First activity for this task: notify listeners so widgets that
    // showed a download button rebuild into the progress state.
    if (isNew) _bumpStatusRevision();
  }

  /// Removes a notifier from the active map without disposing it.
  /// Mounted [ValueListenableBuilder]s may still hold a reference and will
  /// unsubscribe during their next build/unmount; disposing eagerly would
  /// hit "used after disposed" assertions.
  void _retireProgressNotifier(String taskId) {
    final notifier = _downloadProgress.remove(taskId);
    if (notifier != null) _retiredProgressNotifiers.add(notifier);
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

  bool? cachedStatus(String id, DownloadType type) =>
      _fileStatusCache[_statusKey(id, type)];

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

  Future<void> cancelDownload(String id, DownloadType type) async {
    try {
      await FileDownloader().cancelTaskWithId(id);
    } catch (e, st) {
      logError('Failed to cancel download "$id"', e, st);
    }
    _retireProgressNotifier(id);
    _fileStatusCache[_statusKey(id, type)] = false;
    _bumpStatusRevision();
  }

  Future<void> deleteFile(String id, DownloadType type) async {
    try {
      final filePath = _getFilePath(id, type);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }

      _fileStatusCache[_statusKey(id, type)] = false;
      _bumpStatusRevision();
    } catch (e, st) {
      logError('Error deleting file', e, st);
    }
  }

  Future<bool> isFileDownloaded(String id, DownloadType type) async {
    // Check cache first
    final cached = cachedStatus(id, type);
    if (cached != null) return cached;

    // Check file system
    try {
      final exists = await _storage.exists(type, id);

      // Update cache
      _fileStatusCache[_statusKey(id, type)] = exists;
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
    final key = _statusKey(id, type);
    final cached = _fileStatusCache[key];
    if (cached != null) return Future.value(cached);
    return _statusFutures[key] ??= isFileDownloaded(id, type).whenComplete(() {
      _statusFutures.remove(key);
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
      _retiredProgressNotifiers.add(notifier);
    }
    _downloadProgress.clear();
    _bumpStatusRevision();
  }

  Future<void> refreshFileStatus(String id, DownloadType type) async {
    _fileStatusCache.remove(_statusKey(id, type));
    _bumpStatusRevision();
    await isFileDownloaded(id, type);
  }

  void dispose() {
    _updatesSub?.cancel();
    for (final notifier in _downloadProgress.values) {
      notifier.dispose();
    }
    _downloadProgress.clear();
    // Safe to dispose retired notifiers now: the whole service (and every
    // widget listening to it) is going away.
    for (final notifier in _retiredProgressNotifiers) {
      try {
        notifier.dispose();
      } catch (_) {}
    }
    _retiredProgressNotifiers.clear();
    statusRevision.dispose();
  }
}
