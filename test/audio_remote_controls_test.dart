import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/media_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audio_controller_test.dart' show FakeEngine, makeContainer, trackFor;

void main() {
  test('lock-screen next/previous move through the queue', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    final t1 = trackFor();
    final t2 = trackFor(id: 'zikr-2');
    await container.read(audioProvider.notifier).playTrack(t1, queue: [t1, t2]);

    engine.emitRemoteSkip(RemoteSkip.next);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(engine.loads.map((r) => r.trackId), ['zikr-1', 'zikr-2']);
    expect(container.read(audioProvider).track?.id, 'zikr-2');

    engine.emitRemoteSkip(RemoteSkip.previous);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(engine.loads.map((r) => r.trackId), ['zikr-1', 'zikr-2', 'zikr-1']);
    expect(container.read(audioProvider).track?.id, 'zikr-1');
  });

  test('queue position drives which session buttons are offered', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    final t1 = trackFor();
    final t2 = trackFor(id: 'zikr-2');
    final notifier = container.read(audioProvider.notifier);

    await notifier.playTrack(t1, queue: [t1, t2]);
    expect(
      engine.queueNavigation,
      (hasQueue: true, hasPrevious: false, hasNext: true),
    );

    await notifier.playNext();
    expect(
      engine.queueNavigation,
      (hasQueue: true, hasPrevious: true, hasNext: false),
    );

    await notifier.playTrack(trackFor(id: 'standalone'));
    expect(
      engine.queueNavigation,
      (hasQueue: false, hasPrevious: false, hasNext: false),
    );
  });

  test('remote next at the end of the queue is ignored', () async {
    final engine = FakeEngine();
    final container = makeContainer(engine);
    addTearDown(container.dispose);
    addTearDown(engine.dispose);

    final t1 = trackFor();
    final t2 = trackFor(id: 'zikr-2');
    await container.read(audioProvider.notifier).playTrack(t2, queue: [t1, t2]);

    engine.emitRemoteSkip(RemoteSkip.next);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(engine.loads, hasLength(1));
    expect(container.read(audioProvider).track?.id, 'zikr-2');
  });
}
