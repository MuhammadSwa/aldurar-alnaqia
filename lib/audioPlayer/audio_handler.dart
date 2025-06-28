import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart'; // Import rxdart

// Main function to initialize our audio service.
Future<AudioHandler> initAudioService() async {
  JustAudioMediaKit.ensureInitialized();
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.aldurarl_alnaqia.audio',
      androidNotificationChannelName: 'Audio playback for Aldurar Alnaqia',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'drawable/ic_stat_dome',
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  MyAudioHandler() {
    // This is the main change. We combine three streams:
    // 1. The playback event stream, for state changes (playing, paused, etc).
    // 2. The position stream, for continuous position updates.
    // 3. The current media item stream, so we know the total duration.
    //
    // We then pipe the combined result into our own _broadcastState method.
    Rx.combineLatest3<PlaybackEvent, Duration, MediaItem?, PlaybackState>(
      _player.playbackEventStream,
      _player.positionStream,
      mediaItem, // Use the handler's mediaItem stream
      (playbackEvent, position, mediaItem) => _broadcastState(
        playbackEvent: playbackEvent,
        position: position,
        mediaItem: mediaItem,
      ),
    ).listen(
        playbackState.add); // Pipe the stream directly to the playbackState
  }

  // A helper method to create the PlaybackState from the combined streams
  PlaybackState _broadcastState({
    required PlaybackEvent playbackEvent,
    required Duration position,
    required MediaItem? mediaItem,
  }) {
    final playing = _player.playing;
    return PlaybackState(
      controls: [
        // MediaControl.rewind,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        // MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      // THE KEY FIX: Use the position from the positionStream.
      updatePosition: position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: playbackEvent.currentIndex,
    );
  }

  Future<Uri> getImageFileFromAssets(String path) async {
    final byteData = await rootBundle.load(path);

    final file = File('${(await getTemporaryDirectory()).path}/$path');
    await file.create(recursive: true);
    await file.writeAsBytes(byteData.buffer.asUint8List());

    return file.uri;
  }

  // --- The rest of your code remains largely the same ---

  Future<MediaItem> _createMediaItem(
      String id, String url, String title, bool fileExists) async {
    Uri uri;
    if (fileExists) {
      final supportDir = (await getApplicationSupportDirectory()).path;
      uri = Uri.file('$supportDir/narrations/$title.mp3');
    } else {
      uri = Uri.parse(url);
    }
    final artUri = await getImageFileFromAssets('assets/imgs/social_png.png');
    return MediaItem(
        id: id,
        title: title,
        duration: null, // Start with null duration
        artUri: artUri,
        extras: {'uri': uri.toString()});
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'init') {
      final id = extras!['id'] as String;
      final url = extras['url'] as String;
      final title = extras['title'] as String;
      final fileExists = extras['fileExists'] as bool;

      final initialMediaItem =
          await _createMediaItem(id, url, title, fileExists);

      final source = AudioSource.uri(
        Uri.parse(initialMediaItem.extras!['uri'] as String),
        tag: initialMediaItem,
      );

      final loadedDuration = await _player.setAudioSource(source);

      final updatedMediaItem =
          initialMediaItem.copyWith(duration: loadedDuration ?? Duration.zero);

      this.mediaItem.add(updatedMediaItem);

      play();
    } else if (name == 'setSpeed') {
      final speed = extras!['speed'] as double;
      await _player.setSpeed(speed);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    mediaItem.add(null);
    return await super.stop();
  }
}
