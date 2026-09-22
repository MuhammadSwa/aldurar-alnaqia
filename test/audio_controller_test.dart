import 'dart:async';
import 'dart:io';

import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_engine.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart'
    show PlayerState, ProcessingState;

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Test double with the same public surface as [JustAudioEngine].
/// Drives the controller by emitting raw player states; the controller
/// applies all policy (mirrors the production wiring in [AudioController]).
class FakeEngine extends JustAudioEngine {
  FakeEngine();

  final _playerStateCtrl = StreamController<PlayerState>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();
  final _positionCtrl = StreamController<Duration>.broadcast();
  final _bufferedCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration?>.broadcast();

  Duration positionValue = Duration.zero;
  Duration bufferedValue = Duration.zero;
  Duration? durationValue = Duration.zero;

  final List<EngineLoadRequest> loads = [];
  int failNextLoads = 0;
  Exception? loadError;

  /// Optional hook to stall a native load (slow stream) for race tests.
  Future<void> Function(EngineLoadRequest request)? loadGate;

  /// How many times [stop] was called (ghost-audio detection).
  int stops = 0;

  /// Optional hook to stall stop while another command is issued.
  Future<void> Function()? stopGate;

  int playCalls = 0;
  int pauseCalls = 0;
  final List<Duration> seeks = [];
  final List<double> speeds = [];

  @override
  Stream<PlayerState> get playerStateStream => _playerStateCtrl.stream;
  @override
  Stream<String> get errorStream => _errorCtrl.stream;
  @override
  Stream<Duration> get positionStream => _positionCtrl.stream;
  @override
  Stream<Duration> get bufferedPositionStream => _bufferedCtrl.stream;
  @override
  Stream<Duration?> get durationStream => _durationCtrl.stream;

  @override
  Duration get position => positionValue;
  @override
  Duration get bufferedPosition => bufferedValue;
  @override
  Duration? get duration => durationValue;

  void emitPlaying() =>
      _playerStateCtrl.add(PlayerState(true, ProcessingState.ready));

  void emitPaused() =>
      _playerStateCtrl.add(PlayerState(false, ProcessingState.ready));

  void emitLoading() =>
      _playerStateCtrl.add(PlayerState(false, ProcessingState.loading));

  void emitCompleted() =>
      _playerStateCtrl.add(PlayerState(false, ProcessingState.completed));

  void emitIdle() =>
      _playerStateCtrl.add(PlayerState(false, ProcessingState.idle));

  void emitError(String message) => _errorCtrl.add(message);

  void setProgress({
    Duration? position,
    Duration? buffered,
    Duration? duration,
  }) {
    if (position != null) positionValue = position;
    if (buffered != null) bufferedValue = buffered;
    if (duration != null) durationValue = duration;
  }

  void emitProgress() {
    _positionCtrl.add(positionValue);
    _bufferedCtrl.add(bufferedValue);
    _durationCtrl.add(durationValue);
  }

  @override
  Future<void> load(EngineLoadRequest request) async {
    loads.add(request);
    final gate = loadGate;
    if (gate != null) await gate(request);
    if (failNextLoads > 0) {
      failNextLoads--;
      throw loadError ?? Exception('boom');
    }
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    speeds.add(speed);
  }

  @override
  Future<void> stop() async {
    stops++;
    final gate = stopGate;
    if (gate != null) await gate();
  }

  @override
  Future<void> dispose() async {
    await _playerStateCtrl.close();
    await _errorCtrl.close();
    await _positionCtrl.close();
    await _bufferedCtrl.close();
    await _durationCtrl.close();
    await super.dispose();
  }
}

/// StorageService that always reports "not downloaded" so the controller
/// resolves to a remote stream request.
class FakeStorage extends StorageService {
  @override
  Future<bool> exists(DownloadType type, String id) async => false;
  @override
  String pathFor(DownloadType type, String id) => '/fake/$id.${type.extension}';
}

AudioTrack trackFor({String id = 'zikr-1'}) => AudioTrack(
      id: id,
      title: 'ذكر تجريبي',
      remoteUrl: 'https://archive.org/download/x/$id.mp3',
    );

ProviderContainer makeContainer(
  FakeEngine engine, {
  StorageService? storage,
}) {
  return ProviderContainer(
    overrides: [
      audioEngineProvider.overrideWithValue(engine),
      storageProvider.overrideWithValue(storage ?? FakeStorage()),
    ],
  );
}

void main() {
  test('initial state is stopped', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    expect(container.read(audioProvider).status, AudioStatus.stopped);
  });

  test('playTrack resolves to remote stream request and reaches playing',
      () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    await container.read(audioProvider.notifier).playTrack(trackFor());

    expect(engine.loads, hasLength(1));
    final request = engine.loads.single;
    expect(request.isLocal, isFalse, reason: 'FakeStorage has no local file');

    expect(container.read(audioProvider).status, AudioStatus.loading);

    engine.emitPlaying();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioProvider).status, AudioStatus.playing);
  });

  test('progress events update position/buffered/duration', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    await container.read(audioProvider.notifier).playTrack(trackFor());
    engine
      ..setProgress(
        position: const Duration(seconds: 5),
        buffered: const Duration(seconds: 30),
        duration: const Duration(minutes: 20),
      )
      ..emitProgress();
    await Future<void>.delayed(Duration.zero);

    final state = container.read(audioProvider);
    expect(state.position, const Duration(seconds: 5));
    expect(state.buffered, const Duration(seconds: 30));
    expect(state.duration, const Duration(minutes: 20));
  });

  test('completion rewinds and pauses', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    final notifier = container.read(audioProvider.notifier);
    await notifier.playTrack(trackFor());
    // Realistic event order: the fresh load reports playing first; only a
    // completion from the actively-playing track rewinds it. (A completion
    // arriving while still loading is a stale duplicate and is ignored.)
    engine.emitPlaying();
    await Future<void>.delayed(Duration.zero);
    engine.emitCompleted();
    await Future<void>.delayed(Duration.zero);

    final state = container.read(audioProvider);
    expect(state.status, AudioStatus.paused);
    expect(state.position, Duration.zero);
  });

  test('load failure surfaces an error immediately', () async {
    final engine = FakeEngine()
      ..failNextLoads = 99
      ..loadError = Exception('network down');
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    await container.read(audioProvider.notifier).playTrack(trackFor());

    final state = container.read(audioProvider);
    expect(state.status, AudioStatus.error);
    expect(state.errorMessage, isNotNull);
    // No timer-based retries: one attempt for a remote source.
    expect(engine.loads, hasLength(1));
  });

  test('broken local file falls back to streaming once', () async {
    // Create a real temp file so _resolveRequest picks the local path.
    final dir = await Directory.systemTemp.createTemp('audio_test');
    addTearDown(() => dir.delete(recursive: true));
    final localFile = File('${dir.path}/zikr-1.mp3');
    await localFile.writeAsString('fake audio');

    FakeStorage storageWithLocal() {
      return _LocalFakeStorage(localFile.path);
    }

    final engine = FakeEngine()..failNextLoads = 1;
    final container = makeContainer(engine, storage: storageWithLocal());
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    await container.read(audioProvider.notifier).playTrack(trackFor());

    expect(
      engine.loads,
      hasLength(2),
      reason: 'local attempt + one remote fallback',
    );
    expect(engine.loads[0].isLocal, isTrue);
    expect(engine.loads[1].isLocal, isFalse);
    expect(container.read(audioProvider).status, isNot(AudioStatus.error));
  });

  test('async engine failure surfaces an error', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    await container.read(audioProvider.notifier).playTrack(trackFor());
    engine.emitError('connection reset');
    await Future<void>.delayed(Duration.zero);

    final state = container.read(audioProvider);
    expect(state.status, AudioStatus.error);
    expect(state.errorMessage, isNotNull);
  });

  test('error can be retried via togglePlayPause', () async {
    final engine = FakeEngine()..failNextLoads = 1;
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    final notifier = container.read(audioProvider.notifier);
    await notifier.playTrack(trackFor());
    expect(container.read(audioProvider).status, AudioStatus.error);

    await notifier.togglePlayPause();
    expect(engine.loads, hasLength(2));
    expect(container.read(audioProvider).status, AudioStatus.loading);

    engine.emitPlaying();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioProvider).status, AudioStatus.playing);
  });

  test('stopPlayer hides the mini player and clears the track', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    await container.read(audioProvider.notifier).playTrack(trackFor());
    engine.emitPlaying();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioProvider).isVisible, isTrue);

    await container.read(audioProvider.notifier).stopPlayer();

    final state = container.read(audioProvider);
    expect(state.isVisible, isFalse);
    expect(state.track, isNull);
    expect(state.speed, 1.0, reason: 'speed preference survives stops');
  });

  test('a finishing stop cannot clear a newer track', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);
    final notifier = container.read(audioProvider.notifier);

    await notifier.playTrack(trackFor());
    engine.emitPlaying();
    await Future<void>.delayed(Duration.zero);

    final stopGate = Completer<void>();
    engine.stopGate = () => stopGate.future;
    final stopping = notifier.stopPlayer();
    expect(
      container.read(audioProvider).isVisible,
      isFalse,
      reason: 'close should update the UI without waiting for the platform',
    );

    await notifier.playTrack(trackFor(id: 'zikr-2'));
    engine.emitPlaying();
    await Future<void>.delayed(Duration.zero);

    stopGate.complete();
    await stopping;

    final state = container.read(audioProvider);
    expect(state.isVisible, isTrue);
    expect(state.status, AudioStatus.playing);
    expect(state.track?.id, 'zikr-2');
  });

  test('a queue missing its selected track becomes standalone playback',
      () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    await container.read(audioProvider.notifier).playTrack(
      trackFor(),
      queue: [trackFor(id: 'zikr-2')],
    );

    final state = container.read(audioProvider);
    expect(state.track?.id, 'zikr-1');
    expect(state.hasQueue, isFalse);
    expect(state.queueIndex, -1);
  });

  test('a superseded skip load failure cannot hide the newer track', () async {
    // Double-tapped next: the first load hangs on a slow stream, the second
    // one wins and starts playing. When the stale load finally fails, the
    // playing track must survive (the stale load never autoplays).
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);
    final notifier = container.read(audioProvider.notifier);

    await notifier.playTrack(trackFor());
    engine.emitPlaying();
    await Future<void>.delayed(Duration.zero);

    final slowGate = Completer<void>();
    engine.loadGate = (request) async {
      if (request.trackId == 'zikr-2') await slowGate.future;
    };

    final staleLoad = notifier.playTrack(trackFor(id: 'zikr-2'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioProvider).status, AudioStatus.loading);

    await notifier.playTrack(trackFor(id: 'zikr-3'));
    engine.emitPlaying();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioProvider).track?.id, 'zikr-3');

    slowGate.completeError(Exception('stale load failed'));
    await staleLoad;
    await Future<void>.delayed(Duration.zero);

    final state = container.read(audioProvider);
    expect(state.isVisible, isTrue);
    expect(state.status, AudioStatus.playing);
    expect(state.track?.id, 'zikr-3');
  });

  test('idle from our own stop inside a skip load does not hide it', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);
    final notifier = container.read(audioProvider.notifier);

    await notifier.playTrack(trackFor());
    engine.emitPlaying();
    await Future<void>.delayed(Duration.zero);

    final pending = notifier.playTrack(trackFor(id: 'zikr-2'));
    // Loading a new source tears the old stream down, which surfaces as
    // idle while the new track is still loading — ignored while loading.
    engine.emitIdle();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(audioProvider).isVisible, isTrue);
    expect(container.read(audioProvider).status, AudioStatus.loading);

    await pending;
    engine.emitPlaying();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioProvider).track?.id, 'zikr-2');
  });

  test('external stop (notification swipe-away) hides the mini player',
      () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    final notifier = container.read(audioProvider.notifier);
    await notifier.playTrack(trackFor());
    engine.emitPlaying();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioProvider).isVisible, isTrue);

    // The player already halted outside the UI; the controller only syncs
    // UI state and must not call back into engine.stop().
    final stopsBefore = engine.stops;
    engine.emitIdle();
    await Future<void>.delayed(Duration.zero);

    final state = container.read(audioProvider);
    expect(state.isVisible, isFalse);
    expect(state.track, isNull);
    expect(state.speed, 1.0, reason: 'speed preference survives stops');
    expect(engine.stops, stopsBefore, reason: 'no stop recursion');
  });

  test('stop during a slow load prevents ghost audio', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);
    final notifier = container.read(audioProvider.notifier);

    await notifier.playTrack(trackFor());
    engine.emitPlaying();
    await Future<void>.delayed(Duration.zero);
    expect(engine.playCalls, 1);

    final slowGate = Completer<void>();
    engine.loadGate = (request) async {
      if (request.trackId == 'zikr-2') await slowGate.future;
    };

    final pendingLoad = notifier.playTrack(trackFor(id: 'zikr-2'));
    await Future<void>.delayed(Duration.zero);
    await notifier.stopPlayer();
    expect(container.read(audioProvider).isVisible, isFalse);

    // The stale load finishes after the stop but must never autoplay:
    // loads are prepare-only, play happens solely for the wanted load.
    slowGate.complete();
    await pendingLoad;
    await Future<void>.delayed(Duration.zero);

    expect(container.read(audioProvider).isVisible, isFalse);
    expect(
      engine.playCalls,
      1,
      reason: 'stale load must not autoplay after the stop',
    );
  });
}

class _LocalFakeStorage extends FakeStorage {
  _LocalFakeStorage(this.localPath);
  final String localPath;

  @override
  String pathFor(DownloadType type, String id) => localPath;
}
