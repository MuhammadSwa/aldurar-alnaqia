import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aldurar_alnaqia/audio/audio_engine.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/common/helpers/logger.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

/// Orchestrates playback policy on top of [AudioEngine]:
///  * resolves each track's source (downloaded file first, else direct
///    https streaming),
///  * falls back from a broken local file to streaming once,
///  * exposes one immutable [AudioState] for the whole UI.
///
/// Transient network hiccups (buffering, reconnection) are handled inside
/// the native player (ExoPlayer / AVPlayer); this layer only surfaces
/// terminal failures and lets the user retry with [togglePlayPause].
class AudioController extends Notifier<AudioState> {
  AudioEngine get _engine => ref.watch(audioEngineProvider);

  StreamSubscription<EngineEvent>? _eventSub;

  /// The request backing the current load, reused for the local→remote
  /// fallback when the engine reports an async failure.
  EngineLoadRequest? _currentRequest;

  @override
  AudioState build() {
    ref.onDispose(_dispose);

    _eventSub?.cancel();
    _eventSub = _engine.events.listen(_onEngineEvent);

    return const AudioState();
  }

  void _dispose() {
    _eventSub?.cancel();
    _eventSub = null;
  }

  // ---------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------

  /// Plays [track]: prefers the downloaded file when it exists, otherwise
  /// streams the remote URL directly.
  Future<void> playTrack(AudioTrack track) async {
    state = state.copyWith(
      status: AudioStatus.loading,
      track: track,
      clearError: true,
      position: Duration.zero,
      buffered: Duration.zero,
      duration: Duration.zero,
    );

    final request = await _resolveRequest(track);
    _currentRequest = request;
    await _tryLoad(request);
  }

  /// Toggles play/pause; restarts the current track after a terminal error.
  Future<void> togglePlayPause() async {
    switch (state.status) {
      case AudioStatus.playing:
        state = state.copyWith(status: AudioStatus.paused);
        await _engine.pause();
        break;
      case AudioStatus.paused:
      case AudioStatus.loading:
        state = state.copyWith(status: AudioStatus.playing);
        await _engine.play();
        break;
      case AudioStatus.error:
        // Terminal error: start over.
        if (state.track != null) {
          await playTrack(state.track!);
        }
        break;
      case AudioStatus.stopped:
        break;
    }
  }

  Future<void> stopPlayer() async {
    _currentRequest = null;
    await _engine.stop();
    state = AudioState(speed: state.speed);
  }

  Future<void> seek(Duration position) async {
    await _engine.seek(position);
    state = state.copyWith(position: position);
  }

  Future<void> setSpeed(double speed) async {
    state = state.copyWith(speed: speed);
    await _engine.setSpeed(speed);
  }

  // ---------------------------------------------------------------------
  // Source resolution
  // ---------------------------------------------------------------------

  Future<EngineLoadRequest> _resolveRequest(AudioTrack track) async {
    try {
      final storage = ref.read(storageProvider);
      final file = File(storage.pathFor(DownloadType.narrations, track.id));
      if (await file.exists()) {
        return EngineLoadRequest(
          uri: file.path,
          trackId: track.id,
          title: track.title,
          isLocal: true,
        );
      }
    } catch (e) {
      logWarn('Local narration lookup failed for "${track.id}": $e');
    }
    return EngineLoadRequest(
      uri: track.remoteUrl,
      trackId: track.id,
      title: track.title,
      isLocal: false,
    );
  }

  /// Builds the one-time remote-stream fallback for a broken local file,
  /// or null when no fallback applies (already remote, or no track).
  EngineLoadRequest? _remoteFallbackFor(EngineLoadRequest request) {
    final track = state.track;
    if (!request.isLocal || track == null) return null;
    return EngineLoadRequest(
      uri: track.remoteUrl,
      trackId: request.trackId,
      title: request.title,
      isLocal: false,
    );
  }

  /// Loads [request]; on a local-file failure retries once over the network
  /// before surfacing an error.
  Future<void> _tryLoad(EngineLoadRequest request) async {
    try {
      await _engine.load(request);
    } catch (e, st) {
      logError('Audio load failed for "${request.title}"', e, st);
      final fallback = _remoteFallbackFor(request);
      if (fallback != null) {
        _currentRequest = fallback;
        try {
          await _engine.load(fallback);
          return;
        } catch (e2, st2) {
          logError('Audio fallback stream failed for "${request.title}"',
              e2, st2);
        }
      }
      _fail();
    }
  }

  // ---------------------------------------------------------------------
  // Engine events
  // ---------------------------------------------------------------------

  void _onEngineEvent(EngineEvent event) {
    switch (event) {
      case EnginePlaybackChanged(:final playback):
        _onPlaybackState(playback);
        break;
      case EngineProgress(:final position, :final buffered, :final duration):
        state = state.copyWith(
          position: position,
          buffered: buffered,
          duration: duration,
        );
        break;
      case EngineFailed():
        logWarn('Audio engine reported failure');
        final request = _currentRequest;
        // Broken local file that only fails asynchronously: try streaming.
        final fallback =
            request == null ? null : _remoteFallbackFor(request);
        if (fallback != null) {
          _currentRequest = fallback;
          state = state.copyWith(status: AudioStatus.loading);
          unawaited(_tryLoad(fallback));
        } else if (state.track != null &&
            state.status != AudioStatus.stopped) {
          _fail();
        }
        break;
    }
  }

  void _onPlaybackState(EnginePlaybackState engineState) {
    switch (engineState) {
      case EnginePlaybackState.buffering:
        if (state.track != null && state.status != AudioStatus.error) {
          state = state.copyWith(status: AudioStatus.loading);
        }
        break;
      case EnginePlaybackState.playing:
        state =
            state.copyWith(status: AudioStatus.playing, clearError: true);
        break;
      case EnginePlaybackState.paused:
        if (state.status != AudioStatus.error &&
            state.status != AudioStatus.stopped) {
          state = state.copyWith(status: AudioStatus.paused);
        }
        break;
      case EnginePlaybackState.completed:
        // Rewind so the user can replay (previous app behavior).
        state = state.copyWith(
          status: AudioStatus.paused,
          position: Duration.zero,
        );
        _engine.seek(Duration.zero);
        _engine.pause();
        break;
      case EnginePlaybackState.idle:
        // Idle arrives after a notification close (X) which stops the player
        // directly in the handler, bypassing [stopPlayer]. Mirror it into a
        // stopped UI state so the mini player disappears. Ignore while
        // loading: [load] briefly stops the player before setting the new
        // source, and intentional stops already reset the state themselves.
        if (state.track != null &&
            (state.status == AudioStatus.playing ||
                state.status == AudioStatus.paused ||
                state.status == AudioStatus.error)) {
          state = AudioState(speed: state.speed);
        }
        break;
    }
  }

  void _fail() {
    if (state.track == null || state.status == AudioStatus.stopped) return;
    state = state.copyWith(
      status: AudioStatus.error,
      errorMessage: 'تعذّر تشغيل الصوت',
    );
  }
}

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = JustAudioEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final audioProvider =
    NotifierProvider<AudioController, AudioState>(AudioController.new);
