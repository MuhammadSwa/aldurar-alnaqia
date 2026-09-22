import 'dart:async';

import 'package:flutter/foundation.dart';

/// Raw playback state reported by the backend, before the controller applies
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

/// Emitted exactly once per backend stop call, including stops that
/// originate outside the app UI (notification X, swipe-away). The controller
/// resets to the hidden stopped state on receipt; the handler already did
/// the platform work, so this must never call back into stop.
class EngineStopped extends EngineEvent {
  const EngineStopped();
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

/// Framework-facing playback backend. Owns the underlying player instance
/// and normalizes it into a simple event stream; contains no policy logic.
///
/// The interface exists so the audio controller can be unit-tested against
/// a fake implementation. The production implementation is the narration
/// audio handler, which owns the single `just_audio` player
/// (`just_audio` on its native backends: Android → ExoPlayer (Media3),
/// iOS / macOS → AVPlayer, Web → HTML audio) and doubles as the media
/// notification bridge.
///
/// Desktop Linux/Windows have no native just_audio backend; [load] will
/// throw there and the controller surfaces it as a normal error state.
abstract class AudioEngine {
  Stream<EngineEvent> get events;

  /// Loads [request] and starts playing it.
  Future<void> load(EngineLoadRequest request);

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);

  /// Stops playback, dismisses the notification and emits [EngineStopped].
  Future<void> stop();

  Future<void> dispose();
}
