import 'package:aldurar_alnaqia/common/widgets/inline_text.dart';
import 'package:material_ui/material_ui.dart';

/// Gregorian civil date label. Stateless renderer: the caller passes the
/// current date in the prayer timezone. Midnight rollover arrives via the
/// parent's rebuild (nudge timer), so no timer lives here.
class GregorianDateWidget extends StatelessWidget {
  final DateTime today;

  const GregorianDateWidget({super.key, required this.today});

  static const Map<int, String> _arabicMonths = {
    1: 'يناير',
    2: 'فبراير',
    3: 'مارس',
    4: 'أبريل',
    5: 'مايو',
    6: 'يونيو',
    7: 'يوليو',
    8: 'أغسطس',
    9: 'سبتمبر',
    10: 'أكتوبر',
    11: 'نوفمبر',
    12: 'ديسمبر',
  };

  @override
  Widget build(BuildContext context) {
    return InlineTextWidget(
      style: Theme.of(context).textTheme.titleMedium,
      '${today.day} ${_arabicMonths[today.month]} ${today.year}',
      textDirection: TextDirection.rtl,
    );
  }
}
