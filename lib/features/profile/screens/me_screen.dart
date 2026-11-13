import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/appearance.dart';
import '../../auth/data/auth_service.dart';
import '../data/profile_api.dart';

/// The teacher's account: appearance and sign out. A course's own rules (attendance line,
/// grade scale, holidays) live in that course's settings, because every course is separate.
class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  late final Future<Profile> _profile = ProfileApi.me();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Me', style: AppText.screenTitle),
          const SizedBox(height: 16),
          // Who is signed in. Shown while it loads as an empty card, so nothing jumps.
          FutureBuilder<Profile>(
            future: _profile,
            builder: (context, snapshot) {
              final profile = snapshot.data;
              final initials = (profile?.fullName ?? '').trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).take(2).map((word) => word[0].toUpperCase()).join();
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: AppGlass.box(AppRadius.card),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(16)),
                      child: Text(initials, style: AppText.cardTitle.copyWith(color: AppColors.onGreen)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile?.fullName ?? ' ', style: AppText.cardTitle, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(profile?.email ?? (snapshot.hasError ? "Couldn't load your details" : ' '),
                              style: AppText.small.copyWith(color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text("A course's attendance line, grade scale and holidays are in that course's settings.", style: AppText.small.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 20),
          Text('APPEARANCE', style: AppText.label),
          const SizedBox(height: 10),
          // Rebuilds by itself when the choice changes, so the open pill moves at once.
          ValueListenableBuilder<String>(
            valueListenable: Appearance.choice,
            builder: (context, choice, _) => Container(
              padding: const EdgeInsets.all(6),
              decoration: AppGlass.box(AppRadius.inner),
              child: Row(
                children: [
                  for (final (value, label, icon) in [
                    (Appearance.system, 'System', Icons.brightness_auto_rounded),
                    (Appearance.light, 'Light', Icons.light_mode_rounded),
                    (Appearance.dark, 'Dark', Icons.dark_mode_rounded),
                  ])
                    Expanded(
                      child: _AppearanceChoice(label: label, icon: icon, open: choice == value, onTap: () => Appearance.set(value)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('System follows your phone: light in class by day, dark at night.', style: AppText.small.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 20),
          Text('ACCOUNT', style: AppText.label),
          const SizedBox(height: 10),
          Material(
            color: AppColors.card,
            shape: AppGlass.shape(AppRadius.inner),
            elevation: AppGlass.lift,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              title: Text('Sign out', style: AppText.rowTitle.copyWith(color: AppColors.dangerText)),
              onTap: AuthService.signOut,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the three Appearance choices. The open one is the green pill.
class _AppearanceChoice extends StatelessWidget {
  const _AppearanceChoice({required this.label, required this.icon, required this.open, required this.onTap});

  final String label;
  final IconData icon;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: open,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          decoration: BoxDecoration(color: open ? AppColors.green : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: open ? AppColors.onGreen : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(label, style: AppText.button.copyWith(fontSize: 13, color: open ? AppColors.onGreen : AppColors.text)),
            ],
          ),
        ),
      ),
    );
  }
}
