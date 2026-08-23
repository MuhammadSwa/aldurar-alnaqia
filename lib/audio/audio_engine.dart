import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'package:aldurar_alnaqia/common/helpers/logger.dart';

/// Raw playback state reported by the engine, before the controller applies
/// its own policy (e.g. rewind-on-complete, retry-on-error).
enum EnginePlaybackState { buffering, playing, paused, completed, idle }

/// Events emitted by [AudioEngine] for the controller to react to.
sealed class EngineEvent {
  const EngineEvent();
}

class EnginePlaybackChanged extends EngineEvent {
  const EnginePlaybackChanged(this.playback);
  final EnginePlaybackState playback;
}

class EngineProgress extends EngineEvent {
  const EngineProgress({
    required this.position,
    required this.buffered,
    required this.duration,
  });

  final Duration position;
  final Duration buffered;
  final Duration duration;
}

class EngineFailed extends EngineEvent {
  const EngineFailed(this.message);
  final String message;
}

/// What to load: a downloaded file or a remote stream.
@immutable
class EngineLoadRequest {
  const EngineLoadRequest({
    required this.uri,
    required this.trackId,
    required this.title,
    required this.isLocal,
    this.cacheRemote = false,
  });

  /// File path when [isLocal], else an https URL.
  final String uri;
  final String trackId;
  final String title;

  /// Whether [uri] points at a local file (vs a remote stream).
  final bool isLocal;

  /// For remote streams: buffer progressively into an on-disk cache so
  /// network hiccups don't kill long plays and replays are instant.
  final bool cacheRemote;
}

/// Framework-facing playback engine. Owns the underlying player instance and
/// normalizes it into a simple event stream; contains no policy logic.
///
/// The interface exists so [AudioController] can be unit-tested against a
/// fake implementation.
abstract class AudioEngine {
  Stream<EngineEvent> get events;

  /// Loads [request] and starts playing it.
  Future<void> load(EngineLoadRequest request);

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);

  /// Stops playback and releases the loaded source.
  Future<void> stop();

  Future<void> dispose();
}

class JustAudioEngine implements AudioEngine {
  JustAudioEngine() {
    // media_kit backend for Linux/desktop playback (no-op elsewhere).
    JustAudioMediaKit.ensureInitialized();

    _subscriptions.add(_player.playerStateStream.listen((playerState) {
      final processing = playerState.processingState;
      final playing = playerState.playing;

      final EnginePlaybackState mapped;
      if (processing == ProcessingState.loading ||
          processing == ProcessingState.buffering) {
        mapped = EnginePlaybackState.buffering;
      } else if (processing == ProcessingState.completed) {
        mapped = EnginePlaybackState.completed;
      } else if (processing == ProcessingState.idle) {
        // Idle means no source / stopped after error.
        mapped = EnginePlaybackState.idle;
      } else {
        mapped = playing
            ? EnginePlaybackState.playing
            : EnginePlaybackState.paused;
      }
      _emit(EnginePlaybackChanged(mapped));
    }));

    _subscriptions.add(
      _player.playbackEventStream.listen(
        (_) {},
        onError: (Object e, StackTrace st) {
          logWarn('Audio engine playback error: $e');
          _emit(EngineFailed(e.toString()));
        },
      ),
    );

    void pushProgress(Duration position, Duration buffered, Duration total) =>
        _emit(EngineProgress(
          position: position,
          buffered: buffered,
          duration: total,
        ));

    _subscriptions.add(_player.positionStream.listen(
        (p) => pushProgress(p, _player.bufferedPosition,
            _player.duration ?? Duration.zero)));
    _subscriptions.add(_player.bufferedPositionStream.listen(
        (b) => pushProgress(_player.position, b,
            _player.duration ?? Duration.zero)));
    _subscriptions.add(_player.durationStream.listen((d) => pushProgress(
        _player.position, _player.bufferedPosition, d ?? Duration.zero)));
  }

  double _currentSpeed = 1.0;

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final StreamController<EngineEvent> _events =
      StreamController<EngineEvent>.broadcast();

  @override
  Stream<EngineEvent> get events => _events.stream;

  void _emit(EngineEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  MediaItem _mediaItemFor(EngineLoadRequest request) {
    return MediaItem(
      id: request.trackId,
      title: request.title,
      album: 'الطريقة اليسرية',
      artUri: Uri.parse('asset:///assets/imgs/social_png.png'),
    );
  }

  @override
  Future<void> load(EngineLoadRequest request) async {
    await _player.stop();

    final AudioSource source;
    if (request.isLocal) {
      source = AudioSource.file(
        request.uri,
        tag: _mediaItemFor(request),
      );
    } else if (request.cacheRemote) {
      // Experimental just_audio API: streams into a cache file while
      // playing, so network drops don't interrupt long plays and replays
      // are served from disk.
      // ignore: experimental_member_use
      source = LockCachingAudioSource(
        Uri.parse(request.uri),
        tag: _mediaItemFor(request),
      );
    } else {
      source = AudioSource.uri(
        Uri.parse(request.uri),
        tag: _mediaItemFor(request),
      );
    }

    await _player.setAudioSource(source);
    await _player.setSpeed(_currentSpeed);
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) async {
    _currentSpeed = speed;
    await _player.setSpeed(speed);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
  }

  @override
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _events.close();
    await _player.dispose();
  }
}
