import 'package:material_ui/material_ui.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../core/theme/app_theme.dart';

/// TEMPORARY. A phone-sized copy of the "Night foundations" board, to check the
/// theme on a real screen. Not part of the app: delete the whole dev/ folder
/// once real screens exist.
class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _HeroPanel(),
            const SizedBox(height: 26),

            Text('PALETTE', style: AppText.label),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                _Swatch('Ground', AppColors.ground),
                _Swatch('Card', AppColors.card),
                _Swatch('Green', AppColors.green),
                _Swatch('Amber', AppColors.warning),
                _Swatch('Coral', AppColors.danger),
                _Swatch('Violet', AppColors.setup),
                _Swatch('Mint', AppColors.success),
              ],
            ),
            const SizedBox(height: 26),

            Text('TYPE', style: AppText.label),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Good morning', style: AppText.screenTitle),
                    Text('Screen title · Bricolage 800', style: AppText.small.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text('Normalization', style: AppText.rowTitle),
                    Text('Body · Plus Jakarta Sans', style: AppText.small.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text('EB24210106003 · 12 OCT · 87%', style: AppText.mono.copyWith(color: AppColors.green)),
                    Text('Mono · values that line up', style: AppText.small.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),

            Text('CONTROLS', style: AppText.label),
            const SizedBox(height: 12),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                FilledButton(onPressed: () {}, child: const Text('Generate plan')),
                FilledButton.tonal(onPressed: () {}, child: const Text('Secondary')),
                OutlinedButton(onPressed: () {}, child: const Text('Outline')),
                IconButton.filled(
                  onPressed: () {},
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: AppColors.onDanger,
                    fixedSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill('Week 6', AppColors.green, AppColors.onGreen),
                _Pill('Behind', AppColors.warningTint, AppColors.warningText),
                _Pill('Missing mark', AppColors.dangerTint, AppColors.dangerText),
                _Pill('On track', AppColors.successTint, AppColors.successText),
                _Pill('Planned', AppColors.line, AppColors.textOnLine),
              ],
            ),
            const SizedBox(height: 26),

            Text('INPUT', style: AppText.label),
            const SizedBox(height: 12),
            TextField(
              style: AppText.input,
              decoration: const InputDecoration(labelText: 'Course name', hintText: 'Database Systems'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The big green block: the design's "hero panel".
class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT CLASS · IN 40 MIN', style: AppText.label.copyWith(color: AppColors.onGreenSoft)),
          const SizedBox(height: 12),
          Text('Normalization', style: AppText.heroTitle.copyWith(color: AppColors.onGreen)),
          Text('part 3 of 3', style: AppText.heroTitle.copyWith(color: AppColors.onGreenSoft)),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.onGreen,
              foregroundColor: AppColors.green,
            ),
            child: const Text('Take attendance'),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: Border.all(color: AppColors.line),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: AppText.small.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.background, this.foreground);

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(text, style: AppText.pill.copyWith(color: foreground)),
    );
  }
}
