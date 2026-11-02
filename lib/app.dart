import 'package:material_ui/material_ui.dart';

import 'core/theme/app_theme.dart';
import 'dev/theme_preview_screen.dart';

/// The app shell: its name, its theme and the first screen.
/// Later this decides between Sign in (logged out) and Home (logged in).
class UstaadAssistApp extends StatelessWidget {
  const UstaadAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UstaadAssist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.night,
      home: const ThemePreviewScreen(), // temporary, until the real screens exist
    );
  }
}
