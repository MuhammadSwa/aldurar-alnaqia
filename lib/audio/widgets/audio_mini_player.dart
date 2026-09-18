import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/audio/widgets/speed_slider_dialog.dart';
import 'package:aldurar_alnaqia/common/helpers/snackbar.dart';

/// Compact playback bar shown above the bottom navigation while a
/// narration is loaded.
class AudioMiniPlayer extends ConsumerWidget {
  const AudioMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      audioProvider.select((s) => s.isVisible ? s.track : null),
    );
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
    final position = ref.watch(audioProvider.select((s) => s.position));
    final buffered = ref.watch(audioProvider.select((s) => s.buffered));
    final duration = ref.watch(audioProvider.select((s) => s.duration));
    final colorScheme = Theme.of(context).colorScheme;

    final totalMs = duration.inMilliseconds.toDouble();
    final sliderMax = totalMs > 0 ? totalMs : 1.0;
    final positionMs = position.inMilliseconds.toDouble().clamp(0.0, sliderMax);
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
            secondaryActiveColor: colorScheme.primary.withValues(alpha: 0.25),
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
    final hasQueue = ref.watch(audioProvider.select((s) => s.hasQueue));
    final hasNext = ref.watch(audioProvider.select((s) => s.hasNext));
    final hasPrevious = ref.watch(audioProvider.select((s) => s.hasPrevious));

    return Stack(
      alignment: Alignment.center,
      children: [
        const Align(alignment: Alignment.topRight, child: SpeedSliderButton()),
        if (hasQueue)
          const Align(
            alignment: Alignment.topLeft,
            child: AutoAdvanceButton(),
          ),
        Align(
          alignment: Alignment.topCenter,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasQueue) ...[
                _SkipButton(
                  icon: Icons.skip_previous,
                  tooltip: 'السابق',
                  onPressed: hasPrevious
                      ? () => ref.read(audioProvider.notifier).playPrevious()
                      : null,
                ),
                const SizedBox(width: 4),
              ],
              _SkipButton(
                icon: Icons.forward_10,
                tooltip: '+10',
                onPressed: () => _skip(ref, const Duration(seconds: -10)),
              ),
              const SizedBox(width: 8),
              _buildPrimaryButton(context, ref, status),
              const SizedBox(width: 8),
              _SkipButton(
                icon: Icons.replay_10,
                tooltip: '-10',
                onPressed: () => _skip(ref, const Duration(seconds: 10)),
              ),
              if (hasQueue) ...[
                const SizedBox(width: 4),
                _SkipButton(
                  icon: Icons.skip_next,
                  tooltip: 'التالي',
                  onPressed: hasNext
                      ? () => ref.read(audioProvider.notifier).playNext()
                      : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _skip(WidgetRef ref, Duration delta) {
    final s = ref.read(audioProvider);
    // Nothing loaded yet — just_audio would throw on seek.
    if (s.duration <= Duration.zero) return;

    var target = s.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > s.duration) target = s.duration;

    ref.read(audioProvider.notifier).seek(target);
  }

  Widget _buildPrimaryButton(
    BuildContext context,
    WidgetRef ref,
    AudioStatus status,
  ) {
    final controller = ref.read(audioProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    final Widget child;
    switch (status) {
      case AudioStatus.playing:
        child = IconButton(
          onPressed: controller.togglePlayPause,
          icon: const Icon(Icons.pause),
          color: colorScheme.onSecondaryContainer,
        );
      case AudioStatus.paused:
      case AudioStatus.error:
        child = IconButton(
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
        child = SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: colorScheme.primary),
        );
      case AudioStatus.stopped:
        child = const SizedBox.shrink();
    }

    // Same footprint in every state → the row never re-lays out.
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(child: child),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 28,
      color: colorScheme.onSecondaryContainer,
      tooltip: tooltip,
    );
  }
}

class SpeedSliderButton extends ConsumerWidget {
  const SpeedSliderButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: const Icon(Icons.speed),
      color: colorScheme.onSecondaryContainer,
      tooltip: 'تعديل السرعة',
      onPressed: () => showSliderDialog(
        context: context,
        title: 'تعديل السرعة',
        divisions: 7,
        min: 0.25,
        max: 2.0,
        value: ref.read(audioProvider).speed,
        onChanged: ref.read(audioProvider.notifier).setSpeed,
      ),
    );
  }
}

/// Toggle for continuous playback of the queued azkar list.
///
/// Visible only when the current track belongs to a multi-item queue.
/// When enabled, finishing a track automatically starts the next one
/// (local file when downloaded, otherwise streaming) until the list ends.
class AutoAdvanceButton extends ConsumerWidget {
  const AutoAdvanceButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final autoAdvance = ref.watch(audioProvider.select((s) => s.autoAdvance));
    final position = ref.watch(audioProvider.select((s) => s.queueIndex));
    final total = ref.watch(audioProvider.select((s) => s.queue.length));

    return IconButton(
      icon: Icon(
        autoAdvance ? Icons.repeat_on : Icons.repeat,
      ),
      color:
          autoAdvance ? colorScheme.primary : colorScheme.onSecondaryContainer,
      tooltip: autoAdvance
          ? 'تشغيل متتابع: مفعّل (${position + 1}/$total) — اضغط للإيقاف'
          : 'تشغيل متتابع للقائمة (${position + 1}/$total)',
      onPressed: () => ref.read(audioProvider.notifier).toggleAutoAdvance(),
    );
  }
}
