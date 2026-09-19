import 'package:aldurar_alnaqia/audio/audio_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification stop delegates to the app stop callback', () async {
    final handler = NarrationAudioHandler();
    var stopped = false;
    handler.onExternalStop = () async {
      stopped = true;
    };

    await handler.stop();

    expect(stopped, isTrue);
  });

  test('task removal delegates to the app stop callback', () async {
    final handler = NarrationAudioHandler();
    var stopped = false;
    handler.onExternalStop = () async {
      stopped = true;
    };

    await handler.onTaskRemoved();

    expect(stopped, isTrue);
  });
}
