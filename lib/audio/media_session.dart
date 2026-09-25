import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Track-navigation requests from the lock screen / media notification.
/// They need the controller's queue policy, so the session forwards them
/// instead of acting on the player.
enum RemoteSkip { next, previous }

/// The app's audio_service handler: mirrors the [AudioPlayer] into the
/// system media session (iOS lock screen / Control Center, Android media
/// notification) and routes its buttons back.
///
/// The playlist lives in the audio controller, not in just_audio, so the
/// session is told which queue buttons to offer ([setQueueNavigation]) and
/// reports presses on [remoteSkips]. Play/pause/seek/stop act on the player
/// directly; the controller observes the result through the player streams.
///
/// Buttons: inside a queue, previous/next zikr (disabled at the ends, like
/// the mini player); standalone, ±10 s jumps. iOS shows one button per
/// side, so the two sets are never offered together.
class MediaSessionHandler extends BaseAudioHandler with SeekHandler {
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final StreamController<RemoteSkip> _skips =
      StreamController<RemoteSkip>.broadcast();

  bool _hasQueue = false;
  bool _hasPrevious = false;
  bool _hasNext = false;

  /// Loads in flight (overlapping rapid skips each hold one).
  int _switches = 0;

  /// Whether playback was running when the current switch began.
  bool _playingBeforeSwitch = false;

  Stream<RemoteSkip> get remoteSkips => _skips.stream;

  void attach(AudioPlayer player) {
    detach();
    _player = player;
    _subscriptions
      ..add(
        player.playbackEventStream.listen(
          (_) => _broadcast(),
          // Surfaced (and logged) by the engine's own subscription.
          onError: (Object _) => _broadcast(),
        ),
      )
      ..add(player.playingStream.listen((_) => _broadcast()))
      ..add(player.speedStream.listen((_) => _broadcast()))
      ..add(player.durationStream.listen((_) => _syncDuration()));
  }

  void detach() {
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    _player = null;
  }

  /// Which queue buttons the system UI offers for the current track.
  void setQueueNavigation({
    required bool hasQueue,
    required bool hasPrevious,
    required bool hasNext,
  }) {
    if (hasQueue == _hasQueue &&
        hasPrevious == _hasPrevious &&
        hasNext == _hasNext) {
      return;
    }
    _hasQueue = hasQueue;
    _hasPrevious = hasPrevious;
    _hasNext = hasNext;
    _broadcast();
  }

  /// Starts a track switch: shows [item] right away and reports `loading`
  /// until [endTrackSwitch], hiding the idle state `stop()` passes through.
  /// Reporting idle would tear down the media session (and on Android the
  /// foreground service) between two tracks.
  void beginTrackSwitch(MediaItem item) {
    if (_switches++ == 0) _playingBeforeSwitch = _player?.playing ?? false;
    mediaItem.add(item);
    _broadcast();
  }

  /// Ends a switch started by [beginTrackSwitch] and publishes the real
  /// player state again: idle if the load failed, which ends the session.
  void endTrackSwitch() {
    if (_switches > 0) _switches--;
    _syncDuration();
    _broadcast();
  }

  bool get _switching => _switches > 0;

  /// Lock-screen scrubber and the ±10 s clamp both read the duration from
  /// the media item.
  void _syncDuration() {
    if (_switching) return;
    final item = mediaItem.value;
    final duration = _player?.duration;
    if (item == null || duration == null || item.duration == duration) return;
    mediaItem.add(item.copyWith(duration: duration));
  }

  void _broadcast() {
    final player = _player;
    if (player == null) return;

    final playing = _switching ? _playingBeforeSwitch : player.playing;
    final controls = [
      if (!_hasQueue)
        MediaControl.rewind
      else if (_hasPrevious)
        MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      MediaControl.stop,
      if (!_hasQueue)
        MediaControl.fastForward
      else if (_hasNext)
        MediaControl.skipToNext,
    ];

    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: [
          for (var i = 0; i < controls.length; i++)
            if (controls[i].action != MediaAction.stop) i,
        ],
        processingState: _switching
            ? AudioProcessingState.loading
            : switch (player.processingState) {
                ProcessingState.idle => AudioProcessingState.idle,
                ProcessingState.loading => AudioProcessingState.loading,
                ProcessingState.buffering => AudioProcessingState.buffering,
                ProcessingState.ready => AudioProcessingState.ready,
                ProcessingState.completed => AudioProcessingState.completed,
              },
        playing: playing,
        updatePosition: _switching ? Duration.zero : player.position,
        bufferedPosition: _switching ? Duration.zero : player.bufferedPosition,
        speed: player.speed,
      ),
    );
  }

  // --- Commands from the system UI ---

  @override
  Future<void> play() async => await _player?.play();

  @override
  Future<void> pause() async => await _player?.pause();

  @override
  Future<void> seek(Duration position) async => await _player?.seek(position);

  @override
  Future<void> stop() async => await _player?.stop();

  @override
  Future<void> skipToNext() async {
    if (_hasNext) _skips.add(RemoteSkip.next);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_hasPrevious) _skips.add(RemoteSkip.previous);
  }
}
