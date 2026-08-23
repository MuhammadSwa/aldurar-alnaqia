import 'dart:async';


import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/common/helpers/logger.dart';

// call initPlayer then stop => works fine
// call initplayer after initPlayer => works fine
// calling initPlayer twice then stop => problem
// Based on:
// https://suragch.medium.com/steaming-audio-in-flutter-with-just-audio-7435fcf672bf

/// Framework-agnostic audio playback service.
///
/// Exposes [ValueListenable]s so widgets can rebuild efficiently with
/// [ValueListenableBuilder] without depending on any state-management package.
class AudioPlayerService {
  AudioPlayerService({required StorageService storage}) : _storage = storage {
    // Ensure the media_kit backend is initialized once on service creation
    // (needed for Linux/desktop playback).
    JustAudioMediaKit.ensureInitialized();

    _playerStateSub = _audioPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;
      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        buttonState.value = ButtonState.loading;
      } else if (!isPlaying) {
        buttonState.value = ButtonState.paused;
      } else if (processingState != ProcessingState.completed) {
        buttonState.value = ButtonState.playing;
      } else {
        // Playback completed: reset position and pause to allow replay
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
        buttonState.value = ButtonState.paused;
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

    _bufferedSub = _audioPlayer.bufferedPositionStream.listen((buffered) {
      final oldState = progressBarState.value;
      progressBarState.value = ProgressBarState(
        current: oldState.current,
        buffered: buffered,
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

  final StorageService _storage;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Subscriptions to avoid adding multiple listeners across re-inits
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _bufferedSub;
  StreamSubscription<Duration?>? _durationSub;

  /// The (remote) URL currently loaded, or '' when stopped.
  /// Widgets use this both for visibility of the mini-player bar and for
  /// comparing against a specific zikr's URL.
  final ValueNotifier<String> urlNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> titleNotifier = ValueNotifier<String>('');
  final ValueNotifier<double> speedNotifier = ValueNotifier<double>(1);
  final ValueNotifier<ButtonState> buttonState =
      ValueNotifier<ButtonState>(ButtonState.loading);
  final ValueNotifier<ProgressBarState> progressBarState =
      ValueNotifier<ProgressBarState>(ProgressBarState(
    current: Duration.zero,
    buffered: Duration.zero,
    total: Duration.zero,
  ));

  Future<void> initPlayer(String newUrl, String newTitle, bool fileExists,
      {String? localId}) async {
    // Keep the original (remote) URL in state so UI logic can compare against it
    urlNotifier.value = newUrl;
    titleNotifier.value = newTitle;
    buttonState.value = ButtonState.loading;
    progressBarState.value = ProgressBarState(
      current: Duration.zero,
      buffered: Duration.zero,
      total: Duration.zero,
    );

    try {
      // Reset current playback before setting new source
      await _audioPlayer.stop();

      final art = Uri.parse('asset:///assets/imgs/social_png.png');
      if (fileExists) {
        final id = localId ?? newTitle; // prefer explicit id when provided
        final path = _storage.pathFor(DownloadType.narrations, id);
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.file(path),
            tag: MediaItem(
              id: id,
              title: newTitle,
              album: 'الطريقة اليسرية',
              artUri: art,
            ),
          ),
        );
      } else {
        await _audioPlayer.setAudioSource(
          AudioSource.uri(
            Uri.parse(newUrl),
            tag: MediaItem(
              id: localId ?? newTitle,
              title: newTitle,
              album: 'الطريقة اليسرية',
              artUri: art,
            ),
          ),
        );
      }

      // Apply current speed and start playing
      await _audioPlayer.setSpeed(speedNotifier.value);
      await _audioPlayer.play();
    } catch (e, st) {
      logError('Failed to load audio source', e, st);
      buttonState.value = ButtonState.error;
    }
  }

  void stopPlayer() {
    urlNotifier.value = '';
    // Stop and reset the player gracefully
    _audioPlayer.stop();
    _audioPlayer.seek(Duration.zero);
    progressBarState.value = ProgressBarState(
      current: Duration.zero,
      buffered: Duration.zero,
      total: Duration.zero,
    );
    buttonState.value = ButtonState.paused;
    titleNotifier.value = '';
  }

  void play() => _audioPlayer.play();

  void pause() => _audioPlayer.pause();

  void seek(Duration position) => _audioPlayer.seek(position);

  void setSpeed(double s) {
    speedNotifier.value = s;
    _audioPlayer.setSpeed(s);
  }

  double get currentSpeed => _audioPlayer.speed;
  Stream<double> get speedStream => _audioPlayer.speedStream;

  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _bufferedSub?.cancel();
    _durationSub?.cancel();
    _audioPlayer.dispose();
    urlNotifier.dispose();
    titleNotifier.dispose();
    speedNotifier.dispose();
    buttonState.dispose();
    progressBarState.dispose();
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

enum ButtonState { paused, playing, loading, error }

class AudioControllerWidget extends ConsumerWidget {
  const AudioControllerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(audioPlayerProvider);

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
                child: ValueListenableBuilder<String>(
                  valueListenable: c.titleNotifier,
                  builder: (context, title, _) => Text(title),
                ),
              )
            ],
          ),
          ValueListenableBuilder<ProgressBarState>(
            valueListenable: c.progressBarState,
            builder: (context, progress, _) {
              return ProgressBar(
                progress: progress.current,
                buffered: progress.buffered,
                total: progress.total,
                onSeek: c.seek,
              );
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              const Align(
                  alignment: Alignment.topRight, child: SpeedSliderWidget()),
              Align(
                alignment: Alignment.topCenter,
                child: ValueListenableBuilder<ButtonState>(
                  valueListenable: c.buttonState,
                  builder: (context, state, _) {
                    if (state == ButtonState.paused ||
                        state == ButtonState.error) {
                      return IconButton(
                        onPressed: () {
                          c.play();
                        },
                        icon: const Icon(Icons.play_arrow),
                      );
                    } else if (state == ButtonState.playing) {
                      return IconButton(
                        onPressed: () {
                          c.pause();
                        },
                        icon: const Icon(Icons.pause),
                      );
                    } else if (state == ButtonState.loading) {
                      return const SizedBox(
                        width: 20.0,
                        height: 20.0,
                        child: CircularProgressIndicator(),
                      );
                    }
                    return const SizedBox.shrink();
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

class SpeedSliderWidget extends ConsumerWidget {
  const SpeedSliderWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(audioPlayerProvider);

    return IconButton(
      icon: ValueListenableBuilder<double>(
        valueListenable: c.speedNotifier,
        builder: (context, speed, _) => Text("$speed x",
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      onPressed: () {
        showSliderDialog(
          context: context,
          title: "تعديل السرعة",
          divisions: 10,
          min: 0.5,
          max: 1.5,
          value: c.currentSpeed,
          stream: c.speedStream,
          onChanged: c.setSpeed,
        );
      },
    );
  }
}
