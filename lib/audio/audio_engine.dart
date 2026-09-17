import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:aldurar_alnaqia/audio/audio_handler.dart';
import 'package:aldurar_alnaqia/common/helpers/logger.dart';

/// Raw playback state reported by the engine, before the controller applies
/// its own policy (e.g. rewind-on-complete).
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
  });

  /// File path when [isLocal], else an https URL.
  final String uri;
  final String trackId;
  final String title;

  /// Whether [uri] points at a local file (vs a remote stream).
  final bool isLocal;
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

/// [just_audio] on its native backends:
///
/// * Android → ExoPlayer (Media3),
/// * iOS / macOS → AVPlayer,
/// * Web → HTML audio.
///
/// No extra backend setup is needed. Desktop Linux/Windows have no native
/// just_audio backend; [load] will throw there and the controller surfaces
/// it as a normal error state.
class JustAudioEngine implements AudioEngine {
  /// Optional media-notification bridge; null on platforms without
  /// notification support (desktop) where playback runs bare.
  JustAudioEngine({NarrationAudioHandler? notifications})
      : _notifications = notifications {
    _notifications?.attach(_player);

    _subscriptions.add(
      _player.playerStateStream.listen((playerState) {
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
      }),
    );

    _subscriptions.add(
      _player.playbackEventStream.listen(
        (_) {},
        onError: (Object e, StackTrace st) {
          logWarn('Audio engine playback error: $e');
          _emit(EngineFailed(e.toString()));
        },
      ),
    );

    _subscriptions.add(_player.positionStream.listen((_) => _emitProgress()));
    _subscriptions
        .add(_player.bufferedPositionStream.listen((_) => _emitProgress()));
    _subscriptions.add(_player.durationStream.listen((_) => _emitProgress()));
  }

  double _currentSpeed = 1.0;

  final NarrationAudioHandler? _notifications;
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final StreamController<EngineEvent> _events =
      StreamController<EngineEvent>.broadcast();

  @override
  Stream<EngineEvent> get events => _events.stream;

  void _emit(EngineEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _emitProgress() {
    _emit(
      EngineProgress(
        position: _player.position,
        buffered: _player.bufferedPosition,
        duration: _player.duration ?? Duration.zero,
      ),
    );
  }

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

  @override
  Future<void> load(EngineLoadRequest request) async {
    await _player.stop();

    // Plain progressive streaming: direct https to the server, no localhost
    // proxy, so it works on Android/iOS with no extra platform config.
    final AudioSource source = request.isLocal
        ? AudioSource.file(request.uri)
        : AudioSource.uri(Uri.parse(request.uri));

    // Publish metadata first so the notification shows the new track
    // immediately while the source is still loading.
    _notifications
        ?.setTrackMetadata(_mediaItemFor(request, await _coverArtUri()));

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
    try {
      await _player.stop();
    } catch (_) {
      // Already idle — still dismiss the notification below.
    }
    // Removes the media notification as well. No seek after stop: it
    // would emit extra player events that could resurrect an empty
    // (black) notification after the service is stopped.
    await _notifications?.stop();
  }

  @override
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _events.close();
    await _notifications?.detach();
    await _player.dispose();
  }
}
