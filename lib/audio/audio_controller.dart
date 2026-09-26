import 'dart:async';
import 'dart:io';

import 'package:aldurar_alnaqia/audio/audio_engine.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/audio/media_session.dart';
import 'package:aldurar_alnaqia/common/helpers/logger.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/services/shared_prefs.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show PlayerState, ProcessingState;

/// Orchestrates playback policy on top of [JustAudioEngine]:
///  * resolves each track's source (downloaded file first, else direct
///    https streaming),
///  * falls back from a broken local file to streaming once,
///  * maps raw player streams into one immutable [AudioState] for the UI,
///  * guards against rapid track-switch races with a generation token,
///  * drives the lock screen / notification prev-next buttons from the
///    queue,
///  * persists playback speed across restarts.
///
/// Transient network hiccups (buffering, reconnection) are handled inside
/// the native player (ExoPlayer / AVPlayer); this layer only surfaces
/// terminal failures and lets the user retry with [togglePlayPause].
class AudioController extends Notifier<AudioState> {
  late JustAudioEngine _engine;
  final List<StreamSubscription<dynamic>> _subs = [];

  /// The request backing the current load, reused for the local→remote
  /// fallback when a broken local file fails asynchronously.
  EngineLoadRequest? _currentRequest;

  /// Bumped by [playTrack], [stopPlayer] and external stops (notification
  /// swipe-away); stale loads and their events are ignored when their
  /// generation no longer matches.
  int _generation = 0;

  /// True between "start loading a source" and "source is live". While set,
  /// player events are suppressed so the old track can't paint over the new
  /// one (stop()/setAudioSource() emit transient intermediate states).
  bool _switching = false;

  @override
  AudioState build() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();

    _engine = ref.watch(audioEngineProvider);
    ref.onDispose(_dispose);

    _subs
      ..add(_engine.playerStateStream.listen(_onPlayerState))
      ..add(_engine.errorStream.listen(_onEngineError))
      ..add(_engine.positionStream.listen((_) => _emitProgress()))
      ..add(_engine.bufferedPositionStream.listen((_) => _emitProgress()))
      ..add(_engine.durationStream.listen((_) => _emitProgress()))
      ..add(_engine.remoteSkips.listen(_onRemoteSkip));

    // The session dedupes, so the per-tick progress updates are free.
    listenSelf((_, next) {
      _engine.setQueueNavigation(
        hasQueue: next.hasQueue,
        hasPrevious: next.hasPrevious,
        hasNext: next.hasNext,
      );
    });

    // Restore the persisted speed once per app run. Tests run without
    // initialized prefs — fall back to 1.0 instead of throwing.
    final speed = _storedSpeed();
    if (speed != 1.0) {
      unawaited(_engine.setSpeed(speed));
    }

    return AudioState(speed: speed);
  }

  void _dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
  }

  double _storedSpeed() {
    try {
      return SharedPreferencesService.getPlaybackSpeed();
    } catch (_) {
      return 1;
    }
  }

  // ---------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------

  /// Plays [track]: prefers the downloaded file when it exists, otherwise
  /// streams the remote URL directly.
  ///
  /// When [queue] is given, the track is treated as part of that playlist
  /// (e.g. the slidable azkar list) so the mini player can offer continuous
  /// playback and prev/next navigation. Items missing locally are streamed
  /// automatically on advance, same as a direct tap.
  Future<void> playTrack(AudioTrack track, {List<AudioTrack>? queue}) async {
    if (queue == null) {
      await _loadTrack(track, queue: const <AudioTrack>[], queueIndex: -1);
    } else {
      final index = queue.indexWhere((t) => t.id == track.id);
      // A queue is only useful when it actually contains the selected item.
      // Treat malformed caller input as a normal standalone playback rather
      // than starting at index zero and showing controls for a different
      // track. This also keeps the controller safe for future call sites.
      if (index < 0) {
        logWarn('Audio queue does not contain track "${track.id}"');
        await _loadTrack(track, queue: const <AudioTrack>[], queueIndex: -1);
        return;
      }
      await _loadTrack(
        track,
        queue: List<AudioTrack>.unmodifiable(queue),
        queueIndex: index,
      );
    }
  }

  /// Advances to the next queued track; returns false when there is none.
  Future<bool> playNext() async {
    final next = state.nextTrack;
    if (next == null) return false;
    await _loadTrack(next, queueIndex: state.queueIndex + 1);
    return true;
  }

  /// Goes back to the previous queued track; returns false when at the start.
  Future<bool> playPrevious() async {
    final prev = state.previousTrack;
    if (prev == null) return false;
    await _loadTrack(prev, queueIndex: state.queueIndex - 1);
    return true;
  }

  /// Toggles continuous playback of the queued list.
  void toggleAutoAdvance() {
    state = state.copyWith(autoAdvance: !state.autoAdvance);
  }

  /// Single load path: entering a new queue ([playTrack]), moving inside it
  /// ([playNext]/[playPrevious]/auto-advance), or retrying after an error.
  /// Omitted [queue]/[queueIndex] keep the current values, so retries and
  /// advances never drop the playlist context.
  Future<void> _loadTrack(
    AudioTrack track, {
    List<AudioTrack>? queue,
    int? queueIndex,
  }) async {
    final gen = ++_generation;
    state = state.copyWith(
      status: AudioStatus.loading,
      track: track,
      queue: queue,
      queueIndex: queueIndex,
      clearError: true,
      position: Duration.zero,
      buffered: Duration.zero,
      duration: Duration.zero,
    );

    final request = await _resolveRequest(track);
    // A newer skip/stop started while resolving: abandon, the newer load
    // owns the player now.
    if (gen != _generation) return;
    await _loadRequest(request, gen);
  }

  /// Toggles play/pause; restarts the current track after a terminal error.
  Future<void> togglePlayPause() async {
    switch (state.status) {
      case AudioStatus.playing:
        state = state.copyWith(status: AudioStatus.paused);
        await _engine.pause();
      case AudioStatus.paused || AudioStatus.loading:
        state = state.copyWith(status: AudioStatus.playing);
        await _engine.play();
      case AudioStatus.error:
        // Terminal error: start over. Queue context is preserved by
        // [_loadTrack], so continuous playback and prev/next keep working.
        final track = state.track;
        if (track != null) await _loadTrack(track);
      case AudioStatus.stopped:
        break;
    }
  }

  Future<void> stopPlayer() async {
    // Invalidate any in-flight load so its late completion cannot resurrect
    // state (or leave ghost audio) after the close.
    _resetToStopped();
    await _engine.stop();
  }

  /// Resets UI state to hidden-stopped, preserving user preferences.
  /// Shared by [stopPlayer] (mini-player X) and external stops
  /// (notification swipe-away, where the player already halted — so this
  /// must never call [_engine] again).
  void _resetToStopped() {
    _generation++;
    _currentRequest = null;
    // Hide the player before awaiting platform work. Aside from making close
    // responsive, this prevents a previously requested stop from resetting
    // state after the user has already started another track.
    state = AudioState(speed: state.speed, autoAdvance: state.autoAdvance);
  }

  Future<void> seek(Duration position) async {
    await _engine.seek(position);
    state = state.copyWith(position: position);
  }

  Future<void> setSpeed(double speed) async {
    state = state.copyWith(speed: speed);
    await _engine.setSpeed(speed);
    try {
      SharedPreferencesService.setPlaybackSpeed(speed);
    } catch (_) {
      // Tests / uninitialized prefs: engine + UI already updated.
    }
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
          coverAsset: track.coverAsset,
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
      coverAsset: track.coverAsset,
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
      coverAsset: request.coverAsset ?? track.coverAsset,
    );
  }

  /// Loads [request] (stop → set source → speed). On a local-file failure
  /// retries once over the network before surfacing an error. Playback
  /// starts only if this load is still the wanted one, so a superseded
  /// load (double-tapped skip, close mid-load) never autoplays stale audio.
  /// just_audio serializes player commands, so the interrupting stop() from
  /// a newer action has already landed — nothing to clean up here.
  Future<void> _loadRequest(EngineLoadRequest request, int gen) async {
    _currentRequest = request;
    _switching = true;
    var loaded = false;
    try {
      await _engine.load(request);
      loaded = true;
    } catch (e, st) {
      logError('Audio load failed for "${request.title}"', e, st);
      final fallback = _remoteFallbackFor(request);
      if (fallback != null && gen == _generation) {
        _currentRequest = fallback;
        try {
          await _engine.load(fallback);
          loaded = true;
        } catch (e2, st2) {
          logError(
            'Audio fallback stream failed for "${request.title}"',
            e2,
            st2,
          );
        }
      }
    } finally {
      if (gen == _generation) _switching = false;
    }

    if (gen != _generation) return;
    if (!loaded) {
      _fail();
      return;
    }
    await _engine.play();
  }

  // ---------------------------------------------------------------------
  // Engine events
  // ---------------------------------------------------------------------

  void _emitProgress() {
    if (_switching || state.track == null) return;
    state = state.copyWith(
      position: _engine.position,
      buffered: _engine.bufferedPosition,
      duration: _engine.duration ?? Duration.zero,
    );
  }

  void _onRemoteSkip(RemoteSkip skip) {
    switch (skip) {
      case RemoteSkip.next:
        unawaited(playNext());
      case RemoteSkip.previous:
        unawaited(playPrevious());
    }
  }

  void _onEngineError(String message) {
    if (_switching) return;
    logWarn('Audio engine reported failure: $message');
    final request = _currentRequest;
    // Broken local file that only fails asynchronously: try streaming once.
    final fallback = request == null ? null : _remoteFallbackFor(request);
    if (fallback != null) {
      _currentRequest = fallback;
      state = state.copyWith(status: AudioStatus.loading);
      unawaited(_loadRequest(fallback, _generation));
    } else if (state.track != null && state.status != AudioStatus.stopped) {
      _fail();
    }
  }

  void _onPlayerState(PlayerState playerState) {
    if (_switching) return;
    // After an explicit stop there is no track left for native callbacks
    // to describe, so they must not revive a stopped controller state.
    if (state.track == null) return;

    switch (playerState.processingState) {
      case ProcessingState.idle:
        // External stop (notification swiped away, app task removed):
        // mirror it so the mini player disappears. Intentional in-app stops
        // reset the state themselves before the idle event arrives, and the
        // generation bump below keeps an in-flight load from autoplaying
        // ghost audio after the user dismissed playback.
        if (state.status == AudioStatus.playing ||
            state.status == AudioStatus.paused ||
            state.status == AudioStatus.error) {
          _resetToStopped();
        }
      case ProcessingState.completed:
        // Only the actively-playing track finishing counts. The engine can
        // emit `completed` more than once per finished track; a duplicate
        // arriving while the next track is still loading must not rewind,
        // pause, or skip it.
        if (state.status != AudioStatus.playing &&
            state.status != AudioStatus.paused) {
          break;
        }
        // Continuous mode with more items ahead: stream (or play locally)
        // the next zikr automatically until the list is done.
        if (state.autoAdvance && state.hasNext) {
          final next = state.nextTrack!;
          final nextIndex = state.queueIndex + 1;
          unawaited(_loadTrack(next, queueIndex: nextIndex));
          break;
        }
        // Rewind so the user can replay (previous app behavior).
        state = state.copyWith(
          status: AudioStatus.paused,
          position: Duration.zero,
        );
        unawaited(_engine.seek(Duration.zero));
        unawaited(_engine.pause());
      case ProcessingState.loading || ProcessingState.buffering:
        if (state.status != AudioStatus.error) {
          state = state.copyWith(status: AudioStatus.loading);
        }
      case ProcessingState.ready:
        if (state.status == AudioStatus.stopped) return;
        state = state.copyWith(
          status:
              playerState.playing ? AudioStatus.playing : AudioStatus.paused,
          clearError: true,
        );
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

/// The system media session; overridden in `main` on mobile, where
/// `AudioService.init` creates it. Null elsewhere (tests, desktop).
final mediaSessionProvider = Provider<MediaSessionHandler?>((ref) => null);

final audioEngineProvider = Provider<JustAudioEngine>((ref) {
  final engine = JustAudioEngine(session: ref.watch(mediaSessionProvider));
  ref.onDispose(engine.dispose);
  return engine;
});

final audioProvider =
    NotifierProvider<AudioController, AudioState>(AudioController.new);
