import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'package:aldurar_alnaqia/common/helpers/logger.dart';

/// Interval used by the notification's rewind / fast-forward controls.
const Duration _skipInterval = Duration(seconds: 15);

/// Custom [BaseAudioHandler] that owns the media notification.
///
/// Responsibilities:
///  * publishes rich metadata (title, artist, album, art, duration),
///  * exposes useful controls (rewind -15s / play-pause / forward +15s) plus
///    a seekable progress bar on the lock screen,
///  * stops playback and removes the notification when the user swipes the
///    app away ([onTaskRemoved]),
///  * dismisses cleanly when paused (`androidStopForegroundOnPause`).
///
/// The engine attaches the actual [AudioPlayer] via [attach]; on platforms
/// without media notifications (desktop) no handler is created and the
/// engine runs the bare player instead.
class NarrationAudioHandler extends BaseAudioHandler with SeekHandler {
  NarrationAudioHandler();

  AudioPlayer? _player;
  StreamSubscription<dynamic>? _stateSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<void>? _becomingNoisySub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  bool _resumedAfterInterruption = false;

  /// Wires the handler to the engine's player and starts mirroring its
  /// state into the notification.
  Future<void> attach(AudioPlayer player) async {
    _player = player;

    _stateSub?.cancel();
    _durationSub?.cancel();
    _becomingNoisySub?.cancel();
    _interruptionSub?.cancel();

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
      player.pause();
    });

    // Pause during phone calls / other apps' audio; resume afterwards if
    // the OS says it's fine to do so.
    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        // Ducking just means lower volume; pause only on real interruptions.
        _resumedAfterInterruption = false;
        if (event.type != AudioInterruptionType.duck && player.playing) {
          logInfo('Audio paused: interruption began');
          player.pause();
        }
      } else if (!_resumedAfterInterruption &&
          event.type == AudioInterruptionType.pause) {
        _resumedAfterInterruption = true;
        player.play();
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
    final duration = _player?.duration;
    mediaItem.add(duration == null ? item : item.copyWith(duration: duration));
    _broadcastState();
  }

  void clearTrackMetadata() {
    mediaItem.add(const MediaItem(id: '', title: ''));
    _broadcastState();
  }

  // -------------------------------------------------------------------
  // PlaybackState -> notification controls
  // -------------------------------------------------------------------

  void _broadcastState() {
    final player = _player;
    final playing = player?.playing ?? false;

    final controls = <MediaControl>[
      MediaControl.rewind,
      playing ? MediaControl.pause : MediaControl.play,
      MediaControl.fastForward,
    ];

    playbackState.add(PlaybackState(
      controls: controls,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      processingState: _mapProcessing(player?.processingState),
      playing: playing,
      updatePosition: player?.position ?? Duration.zero,
      bufferedPosition: player?.bufferedPosition ?? Duration.zero,
      speed: player?.speed ?? 1.0,
      queueIndex: 0,
    ));
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
  Future<void> rewind() async {
    final player = _player;
    if (player == null) return;
    final target = player.position - _skipInterval;
    await player.seek(target < Duration.zero ? Duration.zero : target);
  }

  @override
  Future<void> fastForward() async {
    final player = _player;
    if (player == null) return;
    final duration = player.duration;
    final target = player.position + _skipInterval;
    await player.seek(
      duration != null && target > duration ? duration : target,
    );
  }

  @override
  Future<void> stop() async {
    final player = _player;
    if (player != null) {
      await player.stop();
      await player.seek(Duration.zero);
    }
    clearTrackMetadata();
    await super.stop();
  }

  /// The user closed the app (swiped from recents / task manager):
  /// kill playback and remove the notification.
  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }
}
