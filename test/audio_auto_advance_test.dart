import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audio_controller_test.dart'
    show FakeEngine, makeContainer, trackFor;

void main() {
  test('auto-advance loads the next track on completion', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    final t1 = trackFor();
    final t2 = trackFor(id: 'zikr-2');
    final notifier = container.read(audioProvider.notifier);

    await notifier.playTrack(t1, queue: [t1, t2]);
    expect(engine.loads, hasLength(1));

    notifier.toggleAutoAdvance();
    engine.emitPlaying();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    engine.emitCompleted();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(engine.loads, hasLength(2),
        reason: 'completion must trigger a second load',);
    expect(engine.loads[1].trackId, 'zikr-2');
    expect(container.read(audioProvider).track?.id, 'zikr-2');

    engine.emitPlaying();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(audioProvider).status, AudioStatus.playing);
  });

  test('duplicate completed does not rewind or skip the next track', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    final t1 = trackFor();
    final t2 = trackFor(id: 'zikr-2');
    final t3 = trackFor(id: 'zikr-3');
    final notifier = container.read(audioProvider.notifier);

    await notifier.playTrack(t1, queue: [t1, t2, t3]);
    notifier.toggleAutoAdvance();
    engine.emitPlaying();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // First completion advances to track 2.
    engine.emitCompleted();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(engine.loads, hasLength(2));
    expect(container.read(audioProvider).track?.id, 'zikr-2');

    // Stale duplicate for track 1 arrives while track 2 is still loading:
    // must be ignored (no skip to track 3, no rewind-to-paused).
    engine.emitCompleted();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(engine.loads, hasLength(2),
        reason: 'stale completion must not skip ahead',);
    expect(container.read(audioProvider).track?.id, 'zikr-2');
    expect(container.read(audioProvider).status, AudioStatus.loading,
        reason: 'stale completion must not rewind the loading track',);

    // Track 2 starts playing normally.
    engine.emitPlaying();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(audioProvider).status, AudioStatus.playing);
  });
}
