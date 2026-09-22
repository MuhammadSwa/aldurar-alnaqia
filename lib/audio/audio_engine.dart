import 'dart:async';
import 'dart:io';

import 'package:aldurar_alnaqia/common/helpers/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

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

/// Thin facade over just_audio's [AudioPlayer]. All playback policy (queue,
/// auto-advance, fallback, UI state) lives in the audio controller.
///
/// Responsibilities:
///  * builds tagged sources — the `MediaItem` tag is what drives the media
///    notification via just_audio_background,
///  * materializes the bundled cover art to a real file (the Android
///    notification cannot decode `asset:///` URIs — it silently shows a
///    black square),
///  * re-applies the current speed after every load,
///  * surfaces out-of-band playback errors (decode failures, dropped
///    streams) on [errorStream] (load errors are thrown by [load] instead).
///
/// Audio focus, interruptions (phone calls) and headphone-unplug are
/// handled inside just_audio itself (`handleInterruptions` is on by
/// default) — no manual audio_session wiring needed.
///
/// The player is created lazily so unit tests can instantiate the engine
/// (and fakes can extend it) without a native audio backend; listeners are
/// attached exactly once. Desktop Linux/Windows have no native just_audio
/// backend; [load] will throw there and the controller surfaces it as a
/// normal error state.
class JustAudioEngine {
  JustAudioEngine();

  AudioPlayer? _player;
  bool _playerWired = false;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final StreamController<String> _errors = StreamController<String>.broadcast();

  double _currentSpeed = 1;

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
      player.playbackEventStream.listen(
        (_) {},
        onError: (Object e, StackTrace st) {
          logWarn('Audio playback error: $e');
          if (!_errors.isClosed) _errors.add(e.toString());
        },
      ),
    );
  }

  // --- Observation (raw player streams; the controller applies policy) ---

  Stream<PlayerState> get playerStateStream => _audio.playerStateStream;
  Stream<Duration> get positionStream => _audio.positionStream;
  Stream<Duration> get bufferedPositionStream =>
      _audio.bufferedPositionStream;
  Stream<Duration?> get durationStream => _audio.durationStream;

  /// Terminal, out-of-band playback errors (async decode/stream failures).
  Stream<String> get errorStream => _errors.stream;

  Duration get position => _player?.position ?? Duration.zero;
  Duration get bufferedPosition => _player?.bufferedPosition ?? Duration.zero;
  Duration? get duration => _player?.duration;

  // --- Metadata ---

  /// The bundled cover image, extracted to a real file once.
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

  /// Builds the notification metadata. This is the tag the engine attaches
  /// to the audio source; just_audio_background forwards it to the media
  /// notification (title, album, artist, cover art).
  MediaItem _mediaItemFor(EngineLoadRequest request, Uri? artUri) {
    return MediaItem(
      id: request.trackId,
      title: request.title,
      album: 'الدرر النقية',
      artist: 'د يسري جبر',
      artUri: artUri,
    );
  }

  // --- Commands ---

  /// Stops the current source and prepares [request]. Does NOT start
  /// playback — the controller calls [play] only after confirming this
  /// load is still the wanted one (guards rapid track-switch races).
  Future<void> load(EngineLoadRequest request) async {
    final player = _audio;
    await player.stop();

    final tag = _mediaItemFor(request, await _coverArtUri());
    final AudioSource source = request.isLocal
        ? AudioSource.file(request.uri, tag: tag)
        : AudioSource.uri(Uri.parse(request.uri), tag: tag);

    await player.setAudioSource(source);
    await player.setSpeed(_currentSpeed);
  }

  Future<void> play() async {
    final player = _player;
    if (player == null) return;
    await player.play();
  }

  Future<void> pause() async {
    final player = _player;
    if (player == null) return;
    await player.pause();
  }

  Future<void> seek(Duration position) async {
    final player = _player;
    if (player == null) return;
    await player.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    _currentSpeed = speed;
    final player = _player;
    if (player == null) return;
    await player.setSpeed(speed);
  }

  /// Halts playback. With just_audio_background the system notification is
  /// driven by the last tagged source and lingers (paused) until the user
  /// swipes it away.
  Future<void> stop() async {
    final player = _player;
    if (player == null) return;
    await player.stop();
  }

  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _errors.close();
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
}
