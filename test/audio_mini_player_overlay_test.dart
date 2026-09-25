import 'package:aldurar_alnaqia/audio/audio_controller.dart';
import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/audio/widgets/audio_mini_player.dart';
import 'package:aldurar_alnaqia/widgets/main_wrapper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeAudio extends AudioController {
  _FakeAudio(this._initial);

  final AudioState _initial;

  @override
  AudioState build() => _initial;
}

const _playing = AudioState(
  status: AudioStatus.playing,
  track: AudioTrack(
    id: 'wird',
    title: 'ورد',
    remoteUrl: 'https://archive.org/download/x/wird.mp3',
  ),
);

/// Home-indicator inset, in logical pixels.
const double _inset = 34;

const _reader = Key('reader');

/// A fullscreen reader under [AudioMiniPlayerOverlay], on a phone with a
/// home indicator. Returns the bottom inset the reader was built with.
Future<double Function()> _pumpReader(
  WidgetTester tester,
  AudioState audio,
) async {
  tester.view.padding =
      FakeViewPadding(bottom: _inset * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);

  var readerInset = double.nan;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [audioProvider.overrideWith(() => _FakeAudio(audio))],
      child: MaterialApp(
        home: AudioMiniPlayerOverlay(
          child: Builder(
            builder: (context) {
              readerInset = MediaQuery.paddingOf(context).bottom;
              return const ColoredBox(key: _reader, color: Colors.teal);
            },
          ),
        ),
      ),
    ),
  );
  return () => readerInset;
}

void main() {
  testWidgets('with nothing playing, the reader runs to the bottom edge',
      (tester) async {
    final readerInset = await _pumpReader(tester, const AudioState());
    final screen = tester.getSize(find.byType(AudioMiniPlayerOverlay));

    expect(tester.getRect(find.byKey(_reader)).bottom, screen.height);
    // Left to the reader, to keep its last line clear of the indicator.
    expect(readerInset(), _inset);
  });

  testWidgets('the player fills the home-indicator area below the reader',
      (tester) async {
    final readerInset = await _pumpReader(tester, _playing);
    final screen = tester.getSize(find.byType(AudioMiniPlayerOverlay));
    final player = tester.getRect(find.byType(AudioMiniPlayer));

    expect(player.bottom, screen.height);
    expect(tester.getRect(find.byKey(_reader)).bottom, player.top);
    expect(readerInset(), 0);
    // Its controls stay above the indicator.
    expect(
      tester.getRect(find.byIcon(Icons.close)).bottom,
      lessThanOrEqualTo(screen.height - _inset),
    );
  });
}
