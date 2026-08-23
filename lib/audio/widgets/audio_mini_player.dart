import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/utils/show_snackbar.dart';

/// Compact playback bar shown above the bottom navigation while a
/// narration is loaded.
class AudioMiniPlayer extends ConsumerWidget {
  const AudioMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
        audioProvider.select((s) => s.isVisible ? s.track : null));
    if (track == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          _TitleBar(title: track.title),
          const _ProgressBar(),
          const _TransportRow(),
        ],
      ),
    );
  }
}

class _TitleBar extends ConsumerWidget {
  const _TitleBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: () => ref.read(audioProvider.notifier).stopPlayer(),
            icon: const Icon(Icons.close),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Text(title),
        ),
      ],
    );
  }
}

class _ProgressBar extends ConsumerWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position =
        ref.watch(audioProvider.select((s) => s.position));
    final buffered =
        ref.watch(audioProvider.select((s) => s.buffered));
    final duration =
        ref.watch(audioProvider.select((s) => s.duration));

    return ProgressBar(
      progress: position,
      buffered: buffered,
      total: duration,
      onSeek: ref.read(audioProvider.notifier).seek,
    );
  }
}

class _TransportRow extends ConsumerWidget {
  const _TransportRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(audioProvider.select((s) => s.status));

    return Stack(
      alignment: Alignment.center,
      children: [
        const Align(alignment: Alignment.topRight, child: SpeedSliderButton()),
        Align(
          alignment: Alignment.topCenter,
          child: _buildPrimaryButton(context, ref, status),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(
      BuildContext context, WidgetRef ref, AudioStatus status) {
    final controller = ref.read(audioProvider.notifier);

    switch (status) {
      case AudioStatus.playing:
        return IconButton(
          onPressed: controller.togglePlayPause,
          icon: const Icon(Icons.pause),
        );
      case AudioStatus.paused:
      case AudioStatus.error:
        return IconButton(
          onPressed: () {
            if (status == AudioStatus.error) {
              showSnackBar(context, 'جاري إعادة المحاولة...');
            }
            controller.togglePlayPause();
          },
          icon: const Icon(Icons.play_arrow),
        );
      case AudioStatus.loading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(),
        );
      case AudioStatus.stopped:
        return const SizedBox.shrink();
    }
  }
}

class SpeedSliderButton extends ConsumerWidget {
  const SpeedSliderButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(audioProvider.select((s) => s.speed));

    return IconButton(
      icon: Text("$speed x",
          style: const TextStyle(fontWeight: FontWeight.bold)),
      onPressed: () => showSliderDialog(
        context: context,
        title: "تعديل السرعة",
        divisions: 10,
        min: 0.5,
        max: 1.5,
        value: speed,
        onChanged: ref.read(audioProvider.notifier).setSpeed,
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
  required ValueChanged<double> onChanged,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: StatefulBuilder(
        builder: (context, setState) => SizedBox(
          height: 100.0,
          child: Column(
            children: [
              Text('$value$valueSuffix',
                  style: const TextStyle(
                      fontFamily: 'Fixed',
                      fontWeight: FontWeight.bold,
                      fontSize: 24.0)),
              Slider(
                divisions: divisions,
                min: min,
                max: max,
                value: value,
                onChanged: (newValue) => setState(() => value = newValue),
                onChangeEnd: onChanged,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
