// lib/audio_handler.dart

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class AudioPlayerHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  AudioPlayerHandler() {
    // Listen to changes in player state and broadcast them to all clients.
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  // The player's stream is piped to the handler's stream.
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
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
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  // --- Main Public Methods for UI to Call ---

  Future<void> initSong(String newUrl, String newTitle, bool fileExists) async {
    try {
      Duration? duration; // Variable to hold the duration
      if (fileExists) {
        final dir = await getApplicationSupportDirectory();
        final path = '${dir.path}/narrations/$newTitle.mp3';
        // setFilePath returns a Future<Duration?>
        duration = await _player.setFilePath(path);
      } else {
        // setUrl returns a Future<Duration?>
        duration = await _player.setUrl(newUrl);
      }

      // **THE FIX IS HERE**: Include the duration in the MediaItem.
      mediaItem.add(MediaItem(
        id: newUrl, // A unique ID
        title: newTitle,
        artist: "Your App Name", // Optional
        duration: duration ?? Duration.zero, // Use the fetched duration
      ));
    } catch (e) {
      print("Error loading audio source: $e");
    }
  }

  // --- Overridden Methods from BaseAudioHandler ---

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> stop() async {
    await _player.stop();
    mediaItem.add(null);
    await super.stop();
  }
}
