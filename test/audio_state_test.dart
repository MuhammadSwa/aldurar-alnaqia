import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const first = AudioTrack(
    id: 'first',
    title: 'الأول',
    remoteUrl: 'https://example.com/first.mp3',
  );
  const second = AudioTrack(
    id: 'second',
    title: 'الثاني',
    remoteUrl: 'https://example.com/second.mp3',
  );

  test('invalid queue state does not expose navigation', () {
    const state = AudioState(
      track: first,
      queue: [first, second],
      queueIndex: 2,
    );

    expect(state.hasQueue, isFalse);
    expect(state.hasNext, isFalse);
    expect(state.hasPrevious, isFalse);
    expect(state.nextTrack, isNull);
    expect(state.previousTrack, isNull);
  });

  test('a queue for a different current track is not usable', () {
    const state = AudioState(
      track: second,
      queue: [first, second],
      queueIndex: 0,
    );

    expect(state.hasQueue, isFalse);
    expect(state.nextTrack, isNull);
    expect(state.previousTrack, isNull);
  });
}
