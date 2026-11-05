import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/home/screens/main_shell.dart';

/// The app shell: its name, its theme, and which side of the login we're on.
class UstaadAssistApp extends StatelessWidget {
  const UstaadAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UstaadAssist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.night,
      // Rebuilds on every login and logout, so no screen has to navigate for it.
      home: StreamBuilder(
        stream: AuthService.changes,
        builder: (context, _) => AuthService.isLoggedIn ? const MainShell() : const WelcomeScreen(),
      ),
    );
  }
}
