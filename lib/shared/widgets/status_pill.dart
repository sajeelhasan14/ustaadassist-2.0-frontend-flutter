import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';

enum PillTone { neutral, success, warning, danger, setup }

/// A small rounded label such as "On track". Each tone pairs a dark tint with a
/// light text, so it stays readable on the dark cards.
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.tone = PillTone.neutral});

  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      PillTone.neutral => (AppColors.line, AppColors.textOnLine),
      PillTone.success => (AppColors.successTint, AppColors.successText),
      PillTone.warning => (AppColors.warningTint, AppColors.warningText),
      PillTone.danger => (AppColors.dangerTint, AppColors.dangerText),
      PillTone.setup => (AppColors.setupTint, AppColors.setupText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(text, style: AppText.pill.copyWith(color: foreground)),
    );
  }
}
