import 'package:flutter/foundation.dart';

/// Lifecycle of the audio subsystem's current track.
enum AudioStatus {
  /// No track loaded; the mini player is hidden.
  stopped,

  /// A source is being loaded/buffered.
  loading,

  /// Actively playing.
  playing,

  /// Loaded and ready but paused.
  paused,

  /// Playback failed after retries; [AudioState.errorMessage] has details.
  error,
}

/// Identifies the narration currently (or most recently) loaded.
@immutable
class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.title,
    required this.remoteUrl,
    this.isLocal = false,
  });

  /// Stable id of the zikr/narration (used for local-file lookup).
  final String id;
  final String title;
  final String remoteUrl;

  /// Whether the engine loaded the downloaded file instead of streaming.
  final bool isLocal;

  @override
  bool operator ==(Object other) =>
      other is AudioTrack &&
      other.id == id &&
      other.title == title &&
      other.remoteUrl == remoteUrl;

  @override
  int get hashCode => Object.hash(id, title, remoteUrl);
}

/// Immutable snapshot of everything the audio UI needs.
@immutable
class AudioState {
  const AudioState({
    this.status = AudioStatus.stopped,
    this.track,
    this.position = Duration.zero,
    this.buffered = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.errorMessage,
  });

  final AudioStatus status;
  final AudioTrack? track;
  final Duration position;
  final Duration buffered;
  final Duration duration;
  final double speed;
  final String? errorMessage;

  bool get isVisible => status != AudioStatus.stopped && track != null;

  bool get isPlayingThisTrack => status == AudioStatus.playing;

  AudioState copyWith({
    AudioStatus? status,
    AudioTrack? track,
    Duration? position,
    Duration? buffered,
    Duration? duration,
    double? speed,
    String? errorMessage,
    bool clearError = false,
    bool clearTrack = false,
  }) {
    return AudioState(
      status: status ?? this.status,
      track: clearTrack ? null : (track ?? this.track),
      position: position ?? this.position,
      buffered: buffered ?? this.buffered,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AudioState &&
      other.status == status &&
      other.track == track &&
      other.position == position &&
      other.buffered == buffered &&
      other.duration == duration &&
      other.speed == speed &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode =>
      Object.hash(status, track, position, buffered, duration, speed,
          errorMessage);
}
