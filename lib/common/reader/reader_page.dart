import 'package:aldurar_alnaqia/audio/audio_state.dart';
import 'package:aldurar_alnaqia/common/reader/reader_scaffold.dart';
import 'package:aldurar_alnaqia/models/azkar_models.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/play_audio_btn_zikr_page.dart';
import 'package:material_ui/material_ui.dart';

/// Wires a [Zikr] into the shared reader chrome: title + audio action.
/// The standalone zikr screen, HeliaNasabScreen and TareeqaSanadScreen are
/// now one-liners that differ only in [child].
class ZikrReaderPage extends StatelessWidget {
  const ZikrReaderPage({
    required this.zikr,
    required this.child,
    this.queue,
    super.key,
  });

  final Zikr zikr;
  final Widget child;

  /// Full playback order for auto-advance; only swipeable collections pass it.
  final List<AudioTrack>? queue;

  @override
  Widget build(BuildContext context) {
    return ReaderScaffold(
      title: zikr.title,
      actions: [
        PlayAudioBtnZikrPage(
          id: zikr.id,
          title: zikr.title,
          url: zikr.url,
          queue: queue,
        ),
      ],
      child: child,
    );
  }
}
