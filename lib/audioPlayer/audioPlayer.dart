import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/get_state_manager.dart';
import 'package:get/instance_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:path_provider/path_provider.dart';

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

  initPlayer(String newUrl, String newTitle, bool fileExists) async {
    url.value = newUrl;
    title.value = newTitle;

    JustAudioMediaKit.ensureInitialized();

    if (fileExists) {
      final String supportDir = await () async {
        final dir = await getApplicationSupportDirectory();
        return dir.path;
      }();
      _audioPlayer.setFilePath('$supportDir/narrations/$newTitle.mp3');
    } else {
      _audioPlayer.setUrl(url.value);
    }

    _audioPlayer.play();

    _audioPlayer.playerStateStream.listen((playerState) {
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
        // TODO: make it go back to 0 with pausing
        // completed
        // _audioPlayer.seek(Duration.zero);
        // _audioPlayer.pause();
      }
    });

    _audioPlayer.positionStream.listen((position) {
      final oldState = progressBarState.value;
      progressBarState.value = ProgressBarState(
        current: position,
        buffered: oldState.buffered,
        total: oldState.total,
      );
    });

    _audioPlayer.bufferedPositionStream.listen((bufferedPosition) {
      final oldState = progressBarState.value;
      progressBarState.value = ProgressBarState(
        current: oldState.current,
        buffered: bufferedPosition,
        total: oldState.total,
      );
    });

    _audioPlayer.durationStream.listen((totalDuration) {
      final oldState = progressBarState.value;
      progressBarState.value = ProgressBarState(
        current: oldState.current,
        buffered: oldState.buffered,
        total: totalDuration ?? Duration.zero,
      );
    });
  }

  void stopPlayer() {
    url.value = '';
    // TODO: read docs and use dispose or stop withthout causing an error;
    _audioPlayer.pause();
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
    final c = Get.put(Controller());

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
    final c = Get.put(Controller());

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
