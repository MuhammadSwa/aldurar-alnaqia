import 'package:go_router/go_router.dart';
import 'package:yosria/models/consts/alhadra_collection.dart';
import 'package:yosria/models/consts/orphans.dart';
import 'package:yosria/router/handle_router.dart';
import 'package:yosria/router/page_transitions.dart';
import 'package:yosria/screens/zikr_screen/zikr_screen.dart';

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
        child: ZikrScreen(title: state.pathParameters['zikr']! ),
        transitionsBuilder: slideTransition,
      );
    },
  );
}
