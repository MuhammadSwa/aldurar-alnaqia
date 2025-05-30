import 'package:go_router/go_router.dart';
import 'package:aldurar_alnaqia/models/consts/alhadra_collection.dart';
import 'package:aldurar_alnaqia/models/consts/orphans.dart';
import 'package:aldurar_alnaqia/router/handle_router.dart';
import 'package:aldurar_alnaqia/router/page_transitions.dart';
import 'package:aldurar_alnaqia/screens/zikr_screen/zikr_screen.dart';

GoRoute zikrPageRoute() {
  return GoRoute(
    path: 'zikr/:zikr',
    pageBuilder: (context, state) {
      // TODO: find a better way to handle helia and azkar week
      final zikr = state.pathParameters['zikr'];

      if (zikr == alhyliaAndNasab.title) {
        return handleHeliaNasab();
      }
      if (zikr == sanadAltareeqa.title) {
        return handleSanadTareeqa();
      }

      return CustomTransitionPage(
        child: ZikrScreen(title: state.pathParameters['zikr']!),
        transitionsBuilder: slideTransition,
      );
    },
  );
}
