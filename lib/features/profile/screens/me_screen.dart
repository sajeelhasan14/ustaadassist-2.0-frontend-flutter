import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';

/// The teacher's account. Design: Night screen 31. Settings arrive with the features they control.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Me', style: AppText.screenTitle),
          const SizedBox(height: 20),
          Text('ACCOUNT', style: AppText.label),
          const SizedBox(height: 10),
          Material(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.inner),
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
