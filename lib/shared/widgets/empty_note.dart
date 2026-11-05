import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';

/// Says why a list is empty and, when it can, offers the one thing to do about it.
class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.title, required this.message, this.action, this.onAction});

  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.cardTitle),
          const SizedBox(height: 6),
          Text(message, style: AppText.body.copyWith(color: AppColors.textMuted)),
          if (action != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
