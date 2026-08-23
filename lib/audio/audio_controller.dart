import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aldurar_alnaqia/audio/audio_engine.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/common/helpers/logger.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

/// Orchestrates playback policy on top of [AudioEngine]:
///  * resolves each track's source (downloaded file first, else a
///    disk-cached stream),
///  * recovers automatically from transient errors (seek back + replay,
///    exponential backoff, local->remote fallback),
///  * exposes one immutable [AudioState] for the whole UI.
class AudioController extends Notifier<AudioState> {
  /// Max consecutive recovery attempts before surfacing an error.
  static const int _maxRetries = 3;

  AudioEngine get _engine => ref.watch(audioEngineProvider);

  StreamSubscription<EngineEvent>? _eventSub;

  /// The request backing the current/last attempted load, reused by retries.
  EngineLoadRequest? _currentRequest;

  int _retryAttempt = 0;
  Timer? _retryTimer;
  bool _stoppedIntentionally = true;

  @override
  AudioState build() {
    ref.onDispose(_dispose);

    _eventSub?.cancel();
    _eventSub = _engine.events.listen(_onEngineEvent);

    return const AudioState();
  }

  void _dispose() {
    _cancelRetry();
    _eventSub?.cancel();
    _eventSub = null;
  }

  // ---------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------

  /// Plays [track]: prefers the downloaded file when it exists, otherwise
  /// streams the remote URL into the on-disk cache.
  Future<void> playTrack(AudioTrack track) async {
    _cancelRetry();
    _stoppedIntentionally = false;
    _retryAttempt = 0;

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
    await _loadWithRetryTracking(request);
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
        // Terminal error: start over with fresh retries.
        if (state.track != null) {
          await playTrack(state.track!);
        }
        break;
      case AudioStatus.stopped:
        break;
    }
  }

  Future<void> stopPlayer() async {
    _cancelRetry();
    _stoppedIntentionally = true;
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
      cacheRemote: true,
    );
  }

  Future<void> _loadWithRetryTracking(EngineLoadRequest request) async {
    try {
      await _engine.load(request);
    } catch (e, st) {
      logError('Audio load failed for "${request.title}"', e, st);
      _scheduleRecovery();
    }
  }

  // ---------------------------------------------------------------------
  // Error recovery
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
        _scheduleRecovery();
        break;
    }
  }

  void _onPlaybackState(EnginePlaybackState engineState) {
    switch (engineState) {
      case EnginePlaybackState.buffering:
        if (!_stoppedIntentionally && state.track != null) {
          state = state.copyWith(status: AudioStatus.loading);
        }
        break;
      case EnginePlaybackState.playing:
        // Successful playback resets the retry counter.
        _retryAttempt = 0;
        _cancelRetry();
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
        // Idle follows intentional stops; unexpected idles arrive together
        // with [EngineFailed] which drives recovery.
        break;
    }
  }

  void _scheduleRecovery() {
    if (_stoppedIntentionally || state.track == null) return;
    if (_retryTimer != null) return; // recovery already pending

    if (_retryAttempt >= _maxRetries) {
      state = state.copyWith(
        status: AudioStatus.error,
        errorMessage: 'تعذّر تشغيل الصوت بعد عدة محاولات',
      );
      return;
    }

    _retryAttempt++;
    final delay = Duration(milliseconds: 500 << (_retryAttempt - 1));
    logInfo('Audio recovery attempt $_retryAttempt/$_maxRetries '
        'in ${delay.inMilliseconds}ms');

    _retryTimer = Timer(delay, () async {
      _retryTimer = null;
      var request = _currentRequest;
      if (request == null || state.track == null) return;

      // If the local file keeps failing, fall back to streaming once.
      if (request.isLocal && _retryAttempt >= 2) {
        request = EngineLoadRequest(
          uri: state.track!.remoteUrl,
          trackId: request.trackId,
          title: request.title,
          isLocal: false,
          cacheRemote: true,
        );
        _currentRequest = request;
      }

      state = state.copyWith(status: AudioStatus.loading);
      await _loadWithRetryTracking(request);
    });
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = JustAudioEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final audioProvider =
    NotifierProvider<AudioController, AudioState>(AudioController.new);
