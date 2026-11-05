import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';

/// The big coloured panel at the top of most screens. Green means "act here",
/// so other tones (warning, danger, setup) are for panels that report a status.
enum HeroTone { green, warning, danger, setup }

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key, required this.child, this.label, this.tone = HeroTone.green});

  final Widget child;
  final String? label;
  final HeroTone tone;

  Color get _background => switch (tone) {
        HeroTone.green => AppColors.green,
        HeroTone.warning => AppColors.warning,
        HeroTone.danger => AppColors.danger,
        HeroTone.setup => AppColors.setup,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: _background, borderRadius: BorderRadius.circular(AppRadius.card)),
      // Dark text everywhere inside: white on these colours is unreadable.
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: AppColors.onGreen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: AppColors.onGreen, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(label!, style: AppText.label.copyWith(color: AppColors.onGreen))),
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
