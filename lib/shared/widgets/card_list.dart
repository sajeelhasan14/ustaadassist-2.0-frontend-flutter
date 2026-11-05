import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Rows inside one rounded card, with a thin line between them.
class CardList extends StatelessWidget {
  const CardList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.inner),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const Divider(),
            child,
          ],
        ],
      ),
    );
  }
}
