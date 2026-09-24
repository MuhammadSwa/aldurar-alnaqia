import 'package:aldurar_alnaqia/router/app_routes.dart';
import 'package:aldurar_alnaqia/widgets/azkar_list_view/zikr_list_view_tile_widget.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the navigation target for a tile from its stable [zikrId] and [index].
typedef ZikrTargetBuilder = ZikrTarget Function(String zikrId, int index);

class AzkarListViewWidget extends StatelessWidget {
  const AzkarListViewWidget({
    // stable ids (zikr, collection, or day-wird ids)
    required this.zikrIds, required this.barTitle, required this.targetBuilder, super.key,
    this.scrollable = true,
  });

  final List<String> zikrIds;

  final String barTitle;
  final ZikrTargetBuilder targetBuilder;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: scrollable
          ? const EdgeInsets.symmetric(vertical: 8)
          : EdgeInsets.zero,
      physics: scrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: zikrIds.length,
      shrinkWrap: true,
      itemBuilder: (context, index) {
        final id = zikrIds[index];
        return ZikrListViewTile(
          zikrId: id,
          target: targetBuilder(id, index),
        );
      },
    );
  }
}
