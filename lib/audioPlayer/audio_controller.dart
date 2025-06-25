// lib/audio_controller.dart

import 'package:get/get.dart';
import 'package:audio_service/audio_service.dart';
import 'audio_handler.dart'; // Import our new handler

class ProgressBarState {
  ProgressBarState({
    required this.current,
    required this.buffered,
    required this.total,
  });
  final Duration current;
  final Duration buffered;
  final Duration total;
}

enum ButtonState { paused, playing, loading }

class AudioController extends GetxController {
  final _audioHandler = Get.find<AudioPlayerHandler>();

  var isPlayerVisible = false.obs;

  final progressBarState = ProgressBarState(
    current: Duration.zero,
    buffered: Duration.zero,
    total: Duration.zero,
  ).obs;

  var buttonState = ButtonState.loading.obs;
  var title = ''.obs; // Title is also metadata, so we'll get it from MediaItem

  @override
  void onInit() {
    super.onInit();
    // Listen to two separate streams now
    _listenToPlaybackState();
    _listenToMediaItem();
  }

  // Listens for changes in play/pause, loading, and progress
  void _listenToPlaybackState() {
    _audioHandler.playbackState.listen((PlaybackState state) {
      final isPlaying = state.playing;
      final processingState = state.processingState;

      if (processingState == AudioProcessingState.loading ||
          processingState == AudioProcessingState.buffering) {
        buttonState.value = ButtonState.loading;
      } else if (!isPlaying) {
        buttonState.value = ButtonState.paused;
      } else if (processingState != AudioProcessingState.completed) {
        buttonState.value = ButtonState.playing;
      } else {
        seek(Duration.zero);
        pause();
      }

      // Update only the progress parts of the state here
      final oldState = progressBarState.value;
      progressBarState.value = ProgressBarState(
        current: state.updatePosition,
        buffered: state.bufferedPosition,
        total: oldState
            .total, // Keep the old total, it's updated by the mediaItem stream
      );
    });
  }

  // **NEW METHOD**: Listens for changes in the song itself (metadata)
  void _listenToMediaItem() {
    _audioHandler.mediaItem.listen((MediaItem? item) {
      // Update title and total duration from the media item
      title.value = item?.title ?? '';

      final oldState = progressBarState.value;
      progressBarState.value = ProgressBarState(
        current: oldState.current,
        buffered: oldState.buffered,
        total: item?.duration ?? Duration.zero, // **THE FIX IS HERE**
      );
    });
  }

  // --- Public methods for the UI to call ---

  Future<void> initPlayer(
      String newUrl, String newTitle, bool fileExists) async {
    isPlayerVisible.value = true;
    // The url and title are now managed by the handler and mediaItem stream
    await _audioHandler.initSong(newUrl, newTitle, fileExists);
    play();
  }

  void stopPlayer() {
    isPlayerVisible.value = false;
    _audioHandler.stop();
  }

  void play() => _audioHandler.play();
  void pause() => _audioHandler.pause();
  void seek(Duration position) => _audioHandler.seek(position);

  void setSpeed(double s) {
    _audioHandler.setSpeed(s);
  }
}
