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
  });

  /// Stable id of the zikr/narration (used for local-file lookup).
  final String id;
  final String title;
  final String remoteUrl;

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
    this.queue = const [],
    this.queueIndex = -1,
    this.autoAdvance = false,
  });

  final AudioStatus status;
  final AudioTrack? track;
  final Duration position;
  final Duration buffered;
  final Duration duration;
  final double speed;
  final String? errorMessage;

  /// Ordered playlist the current track was started from (e.g. the azkar
  /// list the user is sliding through). Empty when the track was played
  /// standalone.
  final List<AudioTrack> queue;

  /// Index of [track] inside [queue], or -1 when there is no queue.
  final int queueIndex;

  /// When true and [hasNext] holds, finishing the current track starts the
  /// next one automatically (each item resolves locally-first, else streams).
  final bool autoAdvance;

  bool get isVisible => status != AudioStatus.stopped && track != null;

  /// Whether this state has a usable multi-track queue for the selected
  /// track. Keeping the validation here makes all queue consumers safe if a
  /// future caller constructs incomplete playlist state.
  bool get hasQueue =>
      queue.length > 1 &&
      queueIndex >= 0 &&
      queueIndex < queue.length &&
      track == queue[queueIndex];

  bool get hasNext =>
      hasQueue && queueIndex >= 0 && queueIndex + 1 < queue.length;

  bool get hasPrevious => hasQueue && queueIndex > 0;

  AudioTrack? get nextTrack => hasNext ? queue[queueIndex + 1] : null;

  AudioTrack? get previousTrack => hasPrevious ? queue[queueIndex - 1] : null;

  AudioState copyWith({
    AudioStatus? status,
    AudioTrack? track,
    Duration? position,
    Duration? buffered,
    Duration? duration,
    double? speed,
    String? errorMessage,
    bool clearError = false,
    List<AudioTrack>? queue,
    int? queueIndex,
    bool? autoAdvance,
  }) {
    return AudioState(
      status: status ?? this.status,
      track: track ?? this.track,
      position: position ?? this.position,
      buffered: buffered ?? this.buffered,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      autoAdvance: autoAdvance ?? this.autoAdvance,
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
      other.errorMessage == errorMessage &&
      listEquals(other.queue, queue) &&
      other.queueIndex == queueIndex &&
      other.autoAdvance == autoAdvance;

  @override
  int get hashCode => Object.hash(
        status,
        track,
        position,
        buffered,
        duration,
        speed,
        errorMessage,
        Object.hashAll(queue),
        queueIndex,
        autoAdvance,
      );
}
