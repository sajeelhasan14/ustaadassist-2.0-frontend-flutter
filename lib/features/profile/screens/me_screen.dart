import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/prompts.dart';
import '../../auth/data/auth_service.dart';
import '../data/profile_api.dart';

/// The teacher's account. Design: Night screen 31. Settings arrive with the features they control.
class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  late Future<num> _line = ProfileApi.attendanceLine();

  Future<void> _changeLine(num current) async {
    final text = await askText(context, title: 'Attendance line', label: 'Percentage', initial: markText(current), number: true);
    final value = num.tryParse(text ?? '');
    if (value == null) return;
    try {
      await ProfileApi.setAttendanceLine(value);
      if (mounted) setState(() { _line = Future.value(value); });
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Me', style: AppText.screenTitle),
          const SizedBox(height: 20),
          Text('ATTENDANCE', style: AppText.label),
          const SizedBox(height: 10),
          Material(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.inner),
            clipBehavior: Clip.antiAlias,
            child: FutureBuilder<num>(
              future: _line,
              builder: (context, snapshot) {
                final line = snapshot.data;
                return ListTile(
                  title: Text('Attendance line', style: AppText.rowTitle),
                  subtitle: Text('Students below this count as short', style: AppText.small.copyWith(color: AppColors.textMuted)),
                  trailing: Text(line == null ? '–' : '${markText(line)}%', style: AppText.mono),
                  onTap: line == null ? null : () => _changeLine(line),
                );
              },
            ),
          ),
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
