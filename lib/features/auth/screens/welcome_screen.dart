import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/hero_panel.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

/// The first screen a logged-out teacher sees. Design: Night screen 23.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.calendar_month_rounded, color: AppColors.onGreen, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Flexible(child: Text('UstaadAssist', style: AppText.cardTitle, overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: ListView(
                  children: [
                    HeroPanel(
                      label: 'SEMESTER PLANNER',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Set it up once. It replans itself.', style: AppText.heroTitle.copyWith(color: AppColors.onGreen)),
                          const SizedBox(height: 16),
                          Text(
                            'Attendance, marks, question papers and result sheets, in one place.',
                            style: AppText.body.copyWith(color: AppColors.onGreenSoft),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _Feature(icon: Icons.document_scanner_rounded, title: 'Scan your class list', subtitle: 'No typing student names'),
                    const SizedBox(height: 12),
                    const _Feature(icon: Icons.auto_awesome_rounded, title: 'Draft question papers', subtitle: 'You review before anything is used'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
                child: const Text('Get started'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.inner)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.successText, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.rowTitle),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.small.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
