import 'dart:async';

import 'package:aldurar_alnaqia/audio/audio_controller.dart'
    show AudioController;
import 'package:aldurar_alnaqia/common/helpers/logger.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// Custom [BaseAudioHandler] that owns the media notification.
///
/// Responsibilities:
///  * publishes rich metadata (title, artist, album, art, duration),
///  * exposes play-pause plus a close (X) control with a seekable
///    progress bar on the lock screen,
///  * stops playback and removes the notification when the user taps close
///    ([stop]) or swipes the app away ([onTaskRemoved]),
///  * dismisses cleanly when paused (`androidStopForegroundOnPause`).
///
/// The engine attaches the actual [AudioPlayer] via [attach]; on platforms
/// without media notifications (desktop) no handler is created and the
/// engine runs the bare player instead.
class NarrationAudioHandler extends BaseAudioHandler with SeekHandler {
  NarrationAudioHandler();

  /// Close (X) button for the notification. Same [MediaAction.stop] action
  /// as [MediaControl.stop] — so the existing [stop] handler runs — but
  /// with a custom `drawable/audio_service_close` icon (bundled in
  /// `android/app/src/main/res/drawable/`) instead of the square stop icon.
  static const closeControl = MediaControl(
    androidIcon: 'drawable/audio_service_close',
    label: 'Close',
    action: MediaAction.stop,
  );

  /// Routes OS-level stop requests (notification X, swipe-away) through the
  /// app's [AudioController.stopPlayer], so the mini player hides in sync
  /// with the notification. Wired once at bootstrap in main.dart; when null,
  /// [stop] falls back to stopping locally.
  Future<void> Function()? onExternalStop;

  AudioPlayer? _player;
  StreamSubscription<dynamic>? _stateSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<void>? _becomingNoisySub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  bool _resumedAfterInterruption = false;

  /// True once [stop] starts, until the next [setTrackMetadata].
  ///
  /// While set, [_broadcastState] is suppressed so late player events
  /// (stop/seek completions arriving after `super.stop()`) can't
  /// resurrect the notification with empty metadata (black square with a
  /// dead stop button).
  bool _stopInProgress = false;

  /// Wires the handler to the engine's player and starts mirroring its
  /// state into the notification.
  Future<void> attach(AudioPlayer player) async {
    _player = player;

    await _stateSub?.cancel();
    await _durationSub?.cancel();
    await _becomingNoisySub?.cancel();
    await _interruptionSub?.cancel();

    _stateSub = player.playerStateStream.listen((_) => _broadcastState());
    _durationSub = player.durationStream.listen((duration) {
      final current = mediaItem.valueOrNull;
      if (current != null && duration != null && current.duration != duration) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });

    final session = await AudioSession.instance;
    // Unplugging headphones should pause, not blast sound from speakers.
    _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
      logInfo('Audio paused: headphones unplugged');
      unawaited(player.pause());
    });

    // Pause during phone calls / other apps' audio; resume afterwards if
    // the OS says it's fine to do so.
    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        // Ducking just means lower volume; pause only on real interruptions.
        _resumedAfterInterruption = false;
        if (event.type != AudioInterruptionType.duck && player.playing) {
          logInfo('Audio paused: interruption began');
          unawaited(player.pause());
        }
      } else if (!_resumedAfterInterruption &&
          event.type == AudioInterruptionType.pause) {
        _resumedAfterInterruption = true;
        unawaited(player.play());
      }
    });
  }

  Future<void> detach() async {
    await _stateSub?.cancel();
    await _durationSub?.cancel();
    await _becomingNoisySub?.cancel();
    await _interruptionSub?.cancel();
    _player = null;
  }

  /// Configures music-focused audio attributes and focus behavior
  /// (Android/iOS only). Safe to call once at bootstrap.
  static Future<void> configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  // -------------------------------------------------------------------
  // Metadata
  // -------------------------------------------------------------------

  void setTrackMetadata(MediaItem item) {
    _stopInProgress = false;
    final duration = _player?.duration;
    mediaItem.add(duration == null ? item : item.copyWith(duration: duration));
    _broadcastState();
  }

  // -------------------------------------------------------------------
  // PlaybackState -> notification controls
  // -------------------------------------------------------------------

  void _broadcastState() {
    // Don't resurrect the notification after stop: late player events
    // arriving after `super.stop()` would otherwise re-show it with
    // empty (black) metadata and a dead stop button.
    if (_stopInProgress) return;
    if (mediaItem.valueOrNull == null) return;

    final player = _player;
    final playing = player?.playing ?? false;

    // Notification buttons: play/pause + close (X). No prev/next/rewind.
    // The X reuses the stop action, so tapping it runs [stop]: playback
    // halts and the notification is dismissed.
    final controls = <MediaControl>[
      if (playing) MediaControl.pause else MediaControl.play,
      closeControl,
    ];

    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
        },
        processingState: _mapProcessing(player?.processingState),
        playing: playing,
        updatePosition: player?.position ?? Duration.zero,
        bufferedPosition: player?.bufferedPosition ?? Duration.zero,
        speed: player?.speed ?? 1.0,
        queueIndex: 0,
      ),
    );
  }

  AudioProcessingState _mapProcessing(ProcessingState? state) {
    switch (state) {
      case ProcessingState.loading:
      case null:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      case ProcessingState.idle:
        return AudioProcessingState.idle;
    }
  }

  // -------------------------------------------------------------------
  // Remote commands (notification / lock screen / headset buttons)
  // -------------------------------------------------------------------

  @override
  Future<void> play() => _player?.play() ?? Future.value();

  @override
  Future<void> pause() => _player?.pause() ?? Future.value();

  @override
  Future<void> seek(Duration position) =>
      _player?.seek(position) ?? Future.value();

  @override
  Future<void> stop() async {
    final external = onExternalStop;
    if (external != null) {
      // Single source of truth: the controller stops the player, dismisses
      // the notification and hides the mini player together.
      await external();
      return;
    }
    await stopLocally();
  }

  /// Stops the player and dismisses the notification without touching app
  /// state. Called by the engine after the controller already reset the UI —
  /// it must never delegate back to [onExternalStop], that would recurse.
  Future<void> stopLocally() async {
    // Idempotent: the notification X can arrive when the player is
    // already stopped (e.g. mini player closed first). Still run
    // `super.stop()` so the notification is always dismissed.
    _stopInProgress = true;
    final player = _player;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {
        // Already idle / no source — notification still needs dismissal.
      }
    }
    // Clear metadata without resurrecting the notification, then push a
    // button-less final state before stopping the service.
    mediaItem.add(null);
    playbackState.add(
      PlaybackState(
        controls: [],
      ),
    );
    await super.stop();
  }

  /// The user closed the app (swiped from recents / task manager):
  /// kill playback and remove the notification.
  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }
}
