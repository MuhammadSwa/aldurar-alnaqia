import 'dart:async';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/instance_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';

// call initPlayer then stop => works fine
// call initplayer after initPlayer => works fine
// classing intPlayer twice then stop => problem
// done with the help of this great article :( but with get_rx.
// https://suragch.medium.com/steaming-audio-in-flutter-with-just-audio-7435fcf672bf
class Controller extends GetxController {
  var url = ''.obs;
  var speed = RxDouble(1);
  var title = ''.obs;

  final AudioPlayer _audioPlayer = AudioPlayer();

  final progressBarState = ProgressBarState(
    current: Duration.zero,
    buffered: Duration.zero,
    total: Duration.zero,
  ).obs;

  var buttonState = _ButtonState.loading.obs;

  // Subscriptions to avoid adding multiple listeners across re-inits
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _bufferedSub;
  StreamSubscription<Duration?>? _durationSub;

  @override
  void onInit() {
    super.onInit();

    // Ensure backend is initialized once on controller creation
    JustAudioMediaKit.ensureInitialized();

    // Attach listeners once; update reactive state for UI
    _playerStateSub = _audioPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;
      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        buttonState.value = _ButtonState.loading;
      } else if (!isPlaying) {
        buttonState.value = _ButtonState.paused;
      } else if (processingState != ProcessingState.completed) {
        buttonState.value = _ButtonState.playing;
      } else {
        // Playback completed: reset position and pause to allow replay
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
        buttonState.value = _ButtonState.paused;
      }
    });

    _positionSub = _audioPlayer.positionStream.listen((position) {
      final oldState = progressBarState.value;
      progressBarState.value = ProgressBarState(
        current: position,
        buffered: oldState.buffered,
        total: oldState.total,
      );
    });

    _bufferedSub = _audioPlayer.bufferedPositionStream.listen((bufferedPosition) {
      final oldState = progressBarState.value;
      progressBarState.value = ProgressBarState(
        current: oldState.current,
        buffered: bufferedPosition,
        total: oldState.total,
      );
    });

    _durationSub = _audioPlayer.durationStream.listen((totalDuration) {
      final oldState = progressBarState.value;
      progressBarState.value = ProgressBarState(
        current: oldState.current,
        buffered: oldState.buffered,
        total: totalDuration ?? Duration.zero,
      );
    });
  }

  initPlayer(String newUrl, String newTitle, bool fileExists, {String? localId}) async {
    // Keep the original (remote) URL in state so UI logic can compare against it
    url.value = newUrl;
    title.value = newTitle;
    buttonState.value = _ButtonState.loading;

    // Reset current playback before setting new source
    await _audioPlayer.stop();

    if (fileExists) {
      final storage = Get.find<StorageService>();
      final id = localId ?? newTitle; // prefer explicit id when provided
      final path = storage.pathFor(DownloadType.narrations, id);
      await _audioPlayer.setFilePath(path);
    } else {
      await _audioPlayer.setUrl(url.value);
    }

    // Apply current speed and start playing
    await _audioPlayer.setSpeed(speed.value);
    await _audioPlayer.play();
  }

  void stopPlayer() {
    url.value = '';
    // Stop and reset the player gracefully
    _audioPlayer.stop();
    _audioPlayer.seek(Duration.zero);
    progressBarState.value = ProgressBarState(
      current: Duration.zero,
      buffered: Duration.zero,
      total: Duration.zero,
    );
    buttonState.value = _ButtonState.paused;
    title.value = '';
  }

  void play() {
    _audioPlayer.play();
  }

  void pause() {
    _audioPlayer.pause();
  }

  void seek(Duration position) {
    _audioPlayer.seek(position);
  }

  void setSpeed(double s) {
    speed.value = s;
    _audioPlayer.setSpeed(s);
  }

  @override
  void onClose() {
    // Dispose the underlying player to free native resources
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _bufferedSub?.cancel();
    _durationSub?.cancel();
    _audioPlayer.dispose();
    super.onClose();
  }
}

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

//
enum _ButtonState { paused, playing, loading }

class AudioControllerWidget extends StatelessWidget {
  const AudioControllerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the singleton instance registered at app start
    final c = Get.find<Controller>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () {
                    c.stopPlayer();
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Obx(() {
                  return Text(c.title.value);
                }),
              )
            ],
          ),
          Obx(() {
            return ProgressBar(
              progress: c.progressBarState.value.current,
              buffered: c.progressBarState.value.buffered,
              total: c.progressBarState.value.total,
              onSeek: c.seek,
            );
          }),
          Stack(
            alignment: Alignment.center,
            children: [
              const Align(
                  alignment: Alignment.topRight, child: SpeedSliderWidget()),
              Align(
                alignment: Alignment.topCenter,
                child: Obx(
                  () {
                    if (c.buttonState.value == _ButtonState.paused) {
                      return IconButton(
                        onPressed: () {
                          c.play();
                        },
                        icon: const Icon(Icons.play_arrow),
                      );
                    } else if (c.buttonState.value == _ButtonState.playing) {
                      return IconButton(
                        onPressed: () {
                          c.pause();
                        },
                        icon: const Icon(Icons.pause),
                      );
                    } else {
                      return const SizedBox(
                        width: 20.0,
                        height: 20.0,
                        child: CircularProgressIndicator(),
                      );
                    }
                  },
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}

void showSliderDialog({
  required BuildContext context,
  required String title,
  required int divisions,
  required double min,
  required double max,
  String valueSuffix = '',
  // TODO: Replace these two by ValueStream.
  required double value,
  required Stream<double> stream,
  required ValueChanged<double> onChanged,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: StreamBuilder<double>(
        stream: stream,
        builder: (context, snapshot) => SizedBox(
          height: 100.0,
          child: Column(
            children: [
              Text('${snapshot.data?.toStringAsFixed(1)}$valueSuffix',
                  style: const TextStyle(
                      fontFamily: 'Fixed',
                      fontWeight: FontWeight.bold,
                      fontSize: 24.0)),
              Slider(
                divisions: divisions,
                min: min,
                max: max,
                value: snapshot.data ?? value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SpeedSliderWidget extends StatelessWidget {
  const SpeedSliderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the singleton instance registered at app start
    final c = Get.find<Controller>();

    return IconButton(
      icon: Obx(() {
        return Text("${c.speed.value}x",
            style: const TextStyle(fontWeight: FontWeight.bold));
      }),
      onPressed: () {
        showSliderDialog(
          context: context,
          title: "تعديل السرعة",
          divisions: 10,
          min: 0.5,
          max: 1.5,
          value: c._audioPlayer.speed,
          stream: c._audioPlayer.speedStream,
          onChanged: c.setSpeed,
        );
      },
    );
  }
}
