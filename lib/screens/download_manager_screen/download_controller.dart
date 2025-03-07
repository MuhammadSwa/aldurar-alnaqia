import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:path_provider/path_provider.dart';

class TaskDownload {
  final String taskId;
  final String filename;
  final String url;
  final Directory directory;
  final BaseDirectory baseDirectory;

  TaskDownload({
    required this.taskId,
    required this.filename,
    required this.url,
    required this.directory,
    required this.baseDirectory,
  });
}

class DownloaderController extends GetxController {
  var queues = <String, ValueNotifier<double>>{}.obs;
  // TODO: refactor this
  // var filesDownloaded = <String>[].obs;
  var filesDownloaded = <String, bool>{}.obs;

  @override
  void onInit() {
    FileDownloader().trackTasks();
    FileDownloader().updates.listen((update) {
      switch (update) {
        case TaskStatusUpdate():
          // TODO: when downloaded add it to downloaded.
          if (update.status == TaskStatus.complete ||
              update.status == TaskStatus.canceled) {
            queues.remove(update.task.taskId);
            // filesDownloaded.add(update.task.taskId);
            filesDownloaded[update.task.taskId] = true;
          }
        case TaskProgressUpdate():
          queues[update.task.taskId] = ValueNotifier(update.progress);
      }
    });
    // TODO: implement onInit
    super.onInit();
  }

  void addTaskToQueue(
      {required String url,
      required String id,
      required String directory}) async {
    final String extension = directory == 'narrations' ? 'mp3' : 'pdf';
    final task = DownloadTask(
      //wed
      filename: '$id.$extension',
      url: url,
      directory: directory,
      baseDirectory: BaseDirectory.applicationSupport,
      taskId: id,
      allowPause: true,
      updates: Updates.statusAndProgress,
    );

    FileDownloader().enqueue(task);
  }

  Future<bool> isFileDownloaded(
      {required String title, required directory}) async {
    final String extension = directory == 'narrations' ? 'mp3' : 'pdf';
    // late String supportDir;
    final String supportDir = await () async {
      final dir = await getApplicationSupportDirectory();
      return dir.path;
    }();
    // );

    final path = '$supportDir/$directory/$title.$extension';

    File file = File(path);

    if (file.existsSync()) {
      filesDownloaded[title] = true;
      return true;
    } else {
      return false;
    }
  }

  deleteFile({required String title, required directory}) async {
    final String extension = directory == 'narrations' ? 'mp3' : 'pdf';

    final String supportDir = await () async {
      final dir = await getApplicationSupportDirectory();
      return dir.path;
    }();

    final path = '$supportDir/$directory/$title.$extension';

    File file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }

    filesDownloaded.remove(title);
    // deletedFiles.add(filename);
  }

  // TODO: group tasks
  // DownloadTsak(group: 'collectionx')

  // TODO: individual or batch download.
  // FileDownloader().downloadBatch(tasks);

  // TODO:
  // await task.expectedFileSize() => show the file size in mb next to icon while downloading.
  // timeRemaining, networkspeed
  // networkSpeedAsString,timeRemainingAsString

  // TODO:
  // FileDownloader().taskCanResume(task);
  // call resume instead of download or enqueue

  // final List<TaskDownload> _downloads = [];
  // List<TaskDownload> get downloads => _downloads;
  //
  // void removeAllDownloads() {
  //   _downloads.clear();
  //   update();
  // }
  //
  // void pauseDownload(TaskDownload download) async {
  //   await FlutterDownloader.pause(taskId: download.taskId);
  //   download.taskId = '';
  //   update();
  // }
  //
  // void resumeDownload(TaskDownload download) async {
  //   await FlutterDownloader.resume(taskId: download.taskId);
  //   download.taskId = '';
  //   update();
  // }
  //
  //
  // void cancelAllDownloads() async {
  //   for (var download in _downloads) {
  //     await FlutterDownloader.cancel(taskId: download.taskId);
  //   }
  //   _downloads.clear();
  //   update();
  // }
  //
  // void pauseAllDownloads() async {
  //   for (var download in _downloads) {
  //     await FlutterDownloader.pause(taskId: download.taskId);
  //   }
  //   _downloads.clear();
  //   update();
  // }
  //
  // void resumeAllDownloads() async {
  //   for (var download in _downloads) {
  //     await FlutterDownloader.resume(taskId: download.taskId);
  //   }
  //   _downloads.clear();
  //   update();
  // }
  //
}
