import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_engine.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/services/storage_service.dart';
import 'package:aldurar_alnaqia/screens/download_manager_screen/download_controller.dart';
import 'package:aldurar_alnaqia/state/app_providers.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeEngine implements AudioEngine {
  final _controller = StreamController<EngineEvent>.broadcast();
  final List<EngineLoadRequest> loads = [];
  int failNextLoads = 0;
  Object? loadError;

  @override
  Stream<EngineEvent> get events => _controller.stream;

  void emit(EngineEvent event) => _controller.add(event);

  @override
  Future<void> load(EngineLoadRequest request) async {
    loads.add(request);
    if (failNextLoads > 0) {
      failNextLoads--;
      throw loadError ?? Exception('boom');
    }
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> stop() async {}

  int disposed = 0;

  @override
  Future<void> dispose() async {
    disposed++;
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

ProviderContainer makeContainer(FakeEngine engine) {
  return ProviderContainer(
    overrides: [
      audioEngineProvider.overrideWithValue(engine),
      storageProvider.overrideWithValue(FakeStorage()),
    ],
  );
}

void main() {
  test('initial state is stopped', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);

    expect(container.read(audioProvider).status, AudioStatus.stopped);
  });

  test('playTrack resolves to cached-stream request and reaches playing',
      () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);

    await container.read(audioProvider.notifier).playTrack(trackFor());

    expect(engine.loads, hasLength(1));
    final request = engine.loads.single;
    expect(request.isLocal, isFalse, reason: 'FakeStorage has no local file');
    expect(request.cacheRemote, isTrue);

    expect(container.read(audioProvider).status, AudioStatus.loading);

    engine.emit(const EnginePlaybackChanged(EnginePlaybackState.playing));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioProvider).status, AudioStatus.playing);
  });

  test('progress events update position/buffered/duration', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);

    await container.read(audioProvider.notifier).playTrack(trackFor());
    engine.emit(const EngineProgress(
      position: Duration(seconds: 5),
      buffered: Duration(seconds: 30),
      duration: Duration(minutes: 20),
    ));
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

    final notifier = container.read(audioProvider.notifier);
    await notifier.playTrack(trackFor());
    engine.emit(const EnginePlaybackChanged(EnginePlaybackState.completed));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(audioProvider);
    expect(state.status, AudioStatus.paused);
    expect(state.position, Duration.zero);
  });

  test('load failure triggers retries with backoff then recovers', () async {
    final engine = FakeEngine()..failNextLoads = 2;
    final container = makeContainer(engine);
    addTearDown(container.dispose);

    // Speed up backoff by waiting through it in real time (0.5s + 1s max).
    final playFuture =
        container.read(audioProvider.notifier).playTrack(trackFor());

    // First load attempt throws synchronously inside load().
    await playFuture;
    // Wait for retry timers (500ms + 1000ms).
    await Future<void>.delayed(const Duration(milliseconds: 1800));

    expect(engine.loads.length, greaterThanOrEqualTo(3),
        reason: 'original attempt + 2 retries');
    expect(container.read(audioProvider).status,
        isNot(AudioStatus.error));

    // Simulate the player finally succeeding.
    engine.emit(const EnginePlaybackChanged(EnginePlaybackState.playing));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioProvider).status, AudioStatus.playing);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('gives up after max retries and surfaces error state', () async {
    final engine = FakeEngine()
      ..failNextLoads = 99
      ..loadError = Exception('network down');
    final container = makeContainer(engine);
    addTearDown(container.dispose);

    await container.read(audioProvider.notifier).playTrack(trackFor());
    // Backoff totals 0.5s + 1s + 2s; wait beyond.
    await Future<void>.delayed(const Duration(milliseconds: 3900));

    final state = container.read(audioProvider);
    expect(state.status, AudioStatus.error);
    expect(state.errorMessage, isNotNull);
    expect(engine.loads.length, 4, reason: 'initial + 3 retries');
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('successful playing resets retry counter', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);

    await container.read(audioProvider.notifier).playTrack(trackFor());

    // A transient failure...
    engine.emit(const EngineFailed('connection reset'));
    await Future<void>.delayed(const Duration(milliseconds: 700));
    // ...then success resets attempts.
    engine.emit(const EnginePlaybackChanged(EnginePlaybackState.playing));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(audioProvider).status, AudioStatus.playing);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('stopPlayer hides the mini player and clears the track', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);

    await container.read(audioProvider.notifier).playTrack(trackFor());
    engine.emit(const EnginePlaybackChanged(EnginePlaybackState.playing));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(audioProvider).isVisible, isTrue);

    await container.read(audioProvider.notifier).stopPlayer();

    final state = container.read(audioProvider);
    expect(state.isVisible, isFalse);
    expect(state.track, isNull);
    expect(state.speed, 1.0, reason: 'speed preference survives stops');
  });
}
