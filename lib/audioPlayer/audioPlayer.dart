import 'package:audio_service/audio_service.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum ButtonState { paused, playing, loading }

class Controller extends GetxController {
  final _audioHandler = Get.find<AudioHandler>();

  // Observable properties
  var currentMediaId = ''.obs;
  var speed = 1.0.obs;
  var title = ''.obs;
  var processState = AudioProcessingState.idle.obs;
  var buttonState = ButtonState.loading.obs;

  // Progress bar properties
  var currentPosition = Duration.zero.obs;
  var bufferedPosition = Duration.zero.obs;
  var totalDuration = Duration.zero.obs;

  @override
  void onInit() {
    super.onInit();
    _listenToPlaybackState();
    _listenToCurrentMediaItem();
  }

  void initPlayer(
      String id, String newUrl, String newTitle, bool fileExists) async {
    await _audioHandler.customAction('init', {
      'id': id,
      'url': newUrl,
      'title': newTitle,
      'fileExists': fileExists,
    });
  }

  void _listenToPlaybackState() {
    _audioHandler.playbackState.listen((PlaybackState state) {
      // Update progress values
      currentPosition.value = state.updatePosition;
      bufferedPosition.value = state.bufferedPosition;

      // Update button state
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
        // When completed, reset
        _audioHandler.seek(Duration.zero);
        _audioHandler.pause();
      }

      // Update speed and processing state
      speed.value = state.speed;
      processState.value = state.processingState;
    });
  }

  void _listenToCurrentMediaItem() {
    _audioHandler.mediaItem.listen((MediaItem? mediaItem) {
      if (mediaItem != null) {
        title.value = mediaItem.title;
        totalDuration.value = mediaItem.duration ?? Duration.zero;
        currentMediaId.value = mediaItem.id;
      } else {
        title.value = '';
        totalDuration.value = Duration.zero;
        currentMediaId.value = '';
      }
    });
  }

  // Playback controls
  void play() => _audioHandler.play();
  void pause() => _audioHandler.pause();
  void seek(Duration position) => _audioHandler.seek(position);

  void setSpeed(double s) {
    _audioHandler.customAction('setSpeed', {'speed': s});
  }

  void stopPlayer() {
    // title.value = '';
    // currentPosition.value = Duration.zero;
    // bufferedPosition.value = Duration.zero;
    // totalDuration.value = Duration.zero;
    _audioHandler.stop();
  }
}

class AudioControllerWidget extends StatelessWidget {
  const AudioControllerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          // Title and close button
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: c.stopPlayer,
                  icon: const Icon(Icons.close),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Obx(() => Text(c.title.value)),
              )
            ],
          ),

          // Progress bar
          Obx(() {
            return ProgressBar(
              progress: c.currentPosition.value,
              buffered: c.bufferedPosition.value,
              total: c.totalDuration.value,
              onSeek: c.seek,
            );
          }),

          // Controls
          Stack(
            alignment: Alignment.center,
            children: [
              const Align(
                  alignment: Alignment.topRight, child: SpeedSliderWidget()),
              Align(
                alignment: Alignment.topCenter,
                child: Obx(() {
                  switch (c.buttonState.value) {
                    case ButtonState.paused:
                      return IconButton(
                        onPressed: c.play,
                        icon: const Icon(Icons.play_arrow),
                      );
                    case ButtonState.playing:
                      return IconButton(
                        onPressed: c.pause,
                        icon: const Icon(Icons.pause),
                      );
                    case ButtonState.loading:
                      return const SizedBox(
                        width: 20.0,
                        height: 20.0,
                        child: CircularProgressIndicator(),
                      );
                  }
                }),
              )
            ],
          )
        ],
      ),
    );
  }
}

class SpeedSliderWidget extends StatelessWidget {
  const SpeedSliderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();

    return IconButton(
      icon: Obx(() {
        return Text("${c.speed.value.toStringAsFixed(1)}x",
            style: const TextStyle(fontWeight: FontWeight.bold));
      }),
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("تعديل السرعة", textAlign: TextAlign.center),
            content: Obx(() => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${c.speed.value.toStringAsFixed(1)}x',
                        style: const TextStyle(
                            fontFamily: 'Fixed',
                            fontWeight: FontWeight.bold,
                            fontSize: 24.0)),
                    Slider(
                      divisions: 10,
                      min: 0.5,
                      max: 1.5,
                      value: c.speed.value,
                      onChanged: c.setSpeed,
                    ),
                  ],
                )),
          ),
        );
      },
    );
  }
}
