import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/audio/widgets/speed_slider_dialog.dart';
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

    // Green-tinted container derived from the app's Material3 color scheme,
    // so it stays distinct from the scaffold background in both light and
    // dark mode (seed is green / greenAccent).
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Material(
        color: colorScheme.secondaryContainer,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TitleBar(title: track.title),
              const _ProgressBar(),
              const _TransportRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleBar extends ConsumerWidget {
  const _TitleBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: () => ref.read(audioProvider.notifier).stopPlayer(),
            icon: const Icon(Icons.close),
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
    final colorScheme = Theme.of(context).colorScheme;

    final totalMs = duration.inMilliseconds.toDouble();
    final sliderMax = totalMs > 0 ? totalMs : 1.0;
    final positionMs =
        position.inMilliseconds.toDouble().clamp(0.0, sliderMax);
    final bufferedFraction = totalMs <= 0
        ? 0.0
        : (buffered.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return Row(
      children: [
        Text(
          _formatDuration(position),
          style: TextStyle(
            color: colorScheme.onSecondaryContainer,
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Slider(
            min: 0,
            max: sliderMax,
            value: positionMs,
            secondaryTrackValue: bufferedFraction,
            onChanged: totalMs <= 0
                ? null
                : (value) => ref
                    .read(audioProvider.notifier)
                    .seek(Duration(milliseconds: value.round())),
            activeColor: colorScheme.primary,
            inactiveColor:
                colorScheme.onSecondaryContainer.withValues(alpha: 0.2),
            secondaryActiveColor:
                colorScheme.primary.withValues(alpha: 0.25),
            thumbColor: colorScheme.primary,
          ),
        ),
        Text(
          _formatDuration(duration),
          style: TextStyle(
            color: colorScheme.onSecondaryContainer,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

String _formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
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
    final colorScheme = Theme.of(context).colorScheme;

    switch (status) {
      case AudioStatus.playing:
        return IconButton(
          onPressed: controller.togglePlayPause,
          icon: const Icon(Icons.pause),
          color: colorScheme.onSecondaryContainer,
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
          color: colorScheme.onSecondaryContainer,
        );
      case AudioStatus.loading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: colorScheme.primary,
          ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: Text("$speed x",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSecondaryContainer,
          )),
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
