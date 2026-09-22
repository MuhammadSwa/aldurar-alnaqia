import 'dart:async';
import 'dart:io';

import 'package:aldurar_alnaqia/audio/audio_engine.dart';
import 'package:aldurar_alnaqia/common/helpers/logger.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Single owner of the player, the queue source and the media notification.
///
/// Previously the player lived in `JustAudioEngine` while this handler only
/// mirrored it via `attach()` — every late `playerState` event then needed
/// guarding (`_stopInProgress`, `stopLocally` vs `stop`, `onExternalStop`)
/// to keep the notification from resurrecting with empty metadata. Now there
/// is one player, one notification mapper driven by `playbackEventStream`
/// (the canonical audio_service pattern), and one [stop] path:
///
/// * mini-player X calls `AudioController.stopPlayer`, which resets UI state
///   and calls [stop];
/// * notification X / swipe-away calls [stop] directly, which does the same
///   platform work and emits [EngineStopped] so the controller resets in
///   sync. The event handler never calls back into [stop], so no recursion.
///
/// This class also implements [AudioEngine] so the controller keeps a single
/// backend seam (faked in tests); on mobile the `AudioService.init` instance
/// is injected as the engine, on desktop a bare instance drives playback
/// with no notification service attached.
class NarrationAudioHandler extends BaseAudioHandler
    with SeekHandler
    implements AudioEngine {
  NarrationAudioHandler();

  /// Close (X) button for the notification. Same [MediaAction.stop] action
  /// as [MediaControl.stop] — so [stop] runs — but with a custom
  /// `drawable/audio_service_close` icon (bundled in
  /// `android/app/src/main/res/drawable/`) instead of the square stop icon.
  static const closeControl = MediaControl(
    androidIcon: 'drawable/audio_service_close',
    label: 'Close',
    action: MediaAction.stop,
  );

  AudioPlayer? _player;
  bool _playerWired = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final StreamController<EngineEvent> _events =
      StreamController<EngineEvent>.broadcast();

  /// True once [stop] starts, until the next [load].
  ///
  /// While set, [_broadcastNotification] is suppressed so late player events
  /// (stop/seek completions arriving after `super.stop()`) can't resurrect
  /// the notification with empty metadata (black square with a dead stop
  /// button).
  bool _stopped = false;
  double _currentSpeed = 1;

  /// Lazily created so unit tests can instantiate the handler without a
  /// native audio backend; listeners are attached exactly once.
  AudioPlayer get _audio {
    var player = _player;
    if (player == null) {
      player = AudioPlayer();
      _player = player;
      _wirePlayer(player);
    }
    return player;
  }

  void _wirePlayer(AudioPlayer player) {
    if (_playerWired) return;
    _playerWired = true;

    _subscriptions.add(
      player.playerStateStream.listen((playerState) {
        final processing = playerState.processingState;
        final playing = playerState.playing;

        final EnginePlaybackState mapped;
        if (processing == ProcessingState.loading ||
            processing == ProcessingState.buffering) {
          mapped = EnginePlaybackState.buffering;
        } else if (processing == ProcessingState.completed) {
          mapped = EnginePlaybackState.completed;
        } else if (processing == ProcessingState.idle) {
          mapped = EnginePlaybackState.idle;
        } else {
          mapped =
              playing ? EnginePlaybackState.playing : EnginePlaybackState.paused;
        }
        _emit(EnginePlaybackChanged(mapped));
      }),
    );

    _subscriptions.add(
      player.playbackEventStream.listen(
        _broadcastNotification,
        onError: (Object e, StackTrace st) {
          logWarn('Audio playback error: $e');
          _emit(EngineFailed(e.toString()));
        },
      ),
    );

    _subscriptions.add(player.positionStream.listen((_) => _emitProgress()));
    _subscriptions
        .add(player.bufferedPositionStream.listen((_) => _emitProgress()));
    _subscriptions.add(player.durationStream.listen((duration) {
      _emitProgress();
      final current = mediaItem.valueOrNull;
      if (current != null && duration != null && current.duration != duration) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    }));

    unawaited(_initSession(player));
  }

  /// Headphone-unplug pauses and call/audio-focus handling. Best-effort:
  /// never throws (tests have no platform session).
  Future<void> _initSession(AudioPlayer player) async {
    try {
      final session = await AudioSession.instance;
      _subscriptions.add(
        session.becomingNoisyEventStream.listen((_) {
          logInfo('Audio paused: headphones unplugged');
          unawaited(player.pause());
        }),
      );
      var resumedAfterInterruption = false;
      _subscriptions.add(
        session.interruptionEventStream.listen((event) {
          if (event.begin) {
            resumedAfterInterruption = false;
            if (event.type != AudioInterruptionType.duck && player.playing) {
              logInfo('Audio paused: interruption began');
              unawaited(player.pause());
            }
          } else if (!resumedAfterInterruption &&
              event.type == AudioInterruptionType.pause) {
            resumedAfterInterruption = true;
            unawaited(player.play());
          }
        }),
      );
    } catch (e) {
      logWarn('Audio session unavailable: $e');
    }
  }

  /// Configures music-focused audio attributes and focus behavior
  /// (Android/iOS only). Safe to call once at bootstrap.
  static Future<void> configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      logWarn('Audio session configuration failed: $e');
    }
  }

  @override
  Stream<EngineEvent> get events => _events.stream;

  void _emit(EngineEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _emitProgress() {
    final player = _player;
    if (player == null) return;
    _emit(
      EngineProgress(
        position: player.position,
        buffered: player.bufferedPosition,
        duration: player.duration ?? Duration.zero,
      ),
    );
  }

  // -------------------------------------------------------------------
  // Cover art
  // -------------------------------------------------------------------

  /// The bundled cover image, extracted to a real file once.
  ///
  /// audio_service's Android artwork loader cannot decode `asset:///` URIs
  /// (Flutter bundle assets are invisible to the native notification code —
  /// it silently fails and the notification shows a black square), so we
  /// materialize the asset on disk and hand the notification a `file://` URI.
  static const String _coverAsset = 'assets/imgs/audio_cover.jpg';
  Uri? _coverFileUri;
  bool _coverResolved = false;

  Future<Uri?> _coverArtUri() async {
    if (_coverResolved) return _coverFileUri;
    _coverResolved = true;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/audio_cover.jpg');
      if (!await file.exists()) {
        final data = await rootBundle.load(_coverAsset);
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      _coverFileUri = Uri.file(file.path);
    } catch (e) {
      logWarn('Failed to materialize audio cover art: $e');
    }
    return _coverFileUri;
  }

  MediaItem _mediaItemFor(EngineLoadRequest request, Uri? artUri) {
    return MediaItem(
      id: request.trackId,
      title: request.title,
      album: 'الدرر النقية',
      artist: 'د يسري جبر',
      artUri: artUri,
    );
  }

  // -------------------------------------------------------------------
  // AudioEngine (playback backend)
  // -------------------------------------------------------------------

  @override
  Future<void> load(EngineLoadRequest request) async {
    // setAudioSource replaces the current source, so a skip never produces
    // the transient idle state that used to be mistaken for "user closed
    // playback".
    //
    // Plain progressive streaming: direct https to the server, no localhost
    // proxy, so it works on Android/iOS with no extra platform config.
    _stopped = false;
    final player = _audio;
    final source = request.isLocal
        ? AudioSource.file(request.uri)
        : AudioSource.uri(Uri.parse(request.uri));

    // Publish metadata first so the notification shows the new track
    // immediately while the source is still loading.
    mediaItem.add(_mediaItemFor(request, await _coverArtUri()));

    await player.setAudioSource(source);
    await player.setSpeed(_currentSpeed);
    await player.play();
  }

  @override
  Future<void> play() async {
    final player = _player;
    if (player == null) return;
    await player.play();
  }

  @override
  Future<void> pause() async {
    final player = _player;
    if (player == null) return;
    await player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    final player = _player;
    if (player == null) return;
    await player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    _currentSpeed = speed;
    final player = _player;
    if (player == null) return;
    await player.setSpeed(speed);
  }

  /// Single stop path for the mini-player X, the notification X and
  /// swipe-away. Stops the player, dismisses the notification and emits
  /// [EngineStopped] so the controller hides the mini player in sync.
  /// Idempotent: safe to call when already stopped.
  /// No seek after stop: it would emit extra player events that could
  /// resurrect an empty (black) notification after the service is stopped.
  @override
  Future<void> stop() async {
    _stopped = true;
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
    playbackState.add(PlaybackState());
    _emit(const EngineStopped());
    try {
      await super.stop();
    } catch (_) {
      // Bare handler (desktop / tests): no service attached.
    }
  }

  @override
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _events.close();
    final player = _player;
    _player = null;
    _playerWired = false;
    if (player != null) {
      try {
        await player.dispose();
      } catch (_) {
        // Native backend already gone (tests / shutdown).
      }
    }
  }

  // -------------------------------------------------------------------
  // Notification (playbackState <- playbackEventStream)
  // -------------------------------------------------------------------

  void _broadcastNotification([PlaybackEvent? _]) {
    // Don't resurrect the notification after stop: late player events
    // arriving after `super.stop()` would otherwise re-show it with
    // empty (black) metadata and a dead stop button.
    if (_stopped) return;
    if (mediaItem.valueOrNull == null) return;

    final player = _player;
    if (player == null) return;
    final playing = player.playing;

    // Notification buttons: play/pause + close (X). No prev/next/rewind.
    // The X reuses the stop action, so tapping it runs [stop]: playback
    // halts and the notification is dismissed.
    playbackState.add(
      PlaybackState(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
          closeControl,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1],
        processingState: _mapProcessing(player.processingState),
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
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

  /// The user closed the app (swiped from recents / task manager):
  /// kill playback and remove the notification.
  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }
}
