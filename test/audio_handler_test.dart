import 'package:aldurar_alnaqia/audio/audio_engine.dart';
import 'package:aldurar_alnaqia/audio/audio_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stop emits EngineStopped and clears the notification', () async {
    final handler = NarrationAudioHandler();
    addTearDown(handler.dispose);

    final events = <EngineEvent>[];
    final sub = handler.events.listen(events.add);
    addTearDown(sub.cancel);

    // No source loaded: stop must still dismiss cleanly (idempotent path
    // taken when the notification X arrives after the mini player closed).
    await handler.stop();
    await Future<void>.delayed(Duration.zero);

    expect(events.whereType<EngineStopped>(), hasLength(1));
    expect(handler.mediaItem.valueOrNull, isNull);
    expect(handler.playbackState.value.controls, isEmpty);
  });

  test('stop is idempotent', () async {
    final handler = NarrationAudioHandler();
    addTearDown(handler.dispose);

    final events = <EngineEvent>[];
    final sub = handler.events.listen(events.add);
    addTearDown(sub.cancel);

    await handler.stop();
    await handler.stop();
    await Future<void>.delayed(Duration.zero);

    expect(events.whereType<EngineStopped>(), hasLength(2));
    expect(handler.mediaItem.valueOrNull, isNull);
  });

  test('task removal stops playback', () async {
    final handler = NarrationAudioHandler();
    addTearDown(handler.dispose);

    final events = <EngineEvent>[];
    final sub = handler.events.listen(events.add);
    addTearDown(sub.cancel);

    await handler.onTaskRemoved();
    await Future<void>.delayed(Duration.zero);

    expect(events.whereType<EngineStopped>(), hasLength(1));
  });
}
