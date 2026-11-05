import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import 'status_pill.dart';

/// The frame of a step-by-step flow: a title with its step pill, a two-line
/// heading (the second line in green), the content, and one main button at the bottom.
class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.title,
    required this.step,
    required this.headingTop,
    required this.headingBottom,
    required this.subtitle,
    required this.children,
    required this.buttonLabel,
    required this.onPressed,
    this.error,
  });

  final String title;
  final String step;
  final String headingTop;
  final String headingBottom;
  final String subtitle;
  final List<Widget> children;
  final String buttonLabel;
  final VoidCallback? onPressed; // null shows the button as busy or unavailable
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: StatusPill(step))),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                children: [
                  Text(headingTop, style: AppText.heroTitle.copyWith(fontSize: 32)),
                  Text(headingBottom, style: AppText.heroTitle.copyWith(fontSize: 32, color: AppColors.green)),
                  const SizedBox(height: 10),
                  Text(subtitle, style: AppText.body.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 20),
                  ...children,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null) ...[
                    Text(error!, style: AppText.small.copyWith(color: AppColors.dangerText)),
                    const SizedBox(height: 10),
                  ],
                  FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
