import 'package:material_ui/material_ui.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/appearance.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/home/screens/main_shell.dart';

/// The app shell: its name, its theme, and which side of the login we're on.
///
/// Light or dark comes from the Me screen's Appearance choice: "System"
/// follows the phone, "Light" and "Dark" stay put. It is a StatefulWidget only
/// so it can hear both kinds of change while the app is open.
class UstaadAssistApp extends StatefulWidget {
  const UstaadAssistApp({super.key});

  @override
  State<UstaadAssistApp> createState() => _UstaadAssistAppState();
}

class _UstaadAssistAppState extends State<UstaadAssistApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // hears the phone switch modes
    Appearance.choice.addListener(_redraw); // hears the teacher pick on the Me screen
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Appearance.choice.removeListener(_redraw);
    super.dispose();
  }

  /// Flutter calls this when the phone switches between light and dark.
  @override
  void didChangePlatformBrightness() => _redraw();

  void _redraw() {
    setState(() {}); // build() below picks the new mode
    // Screens read AppColors directly instead of through the theme, so Flutter
    // doesn't know they need redrawing. Mark every widget on screen as
    // "needs a redraw". This keeps the open screen and anything typed in it.
    void redraw(Element element) {
      element.markNeedsBuild();
      element.visitChildren(redraw);
    }

    (context as Element).visitChildren(redraw);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.isLight = Appearance.isLight(WidgetsBinding.instance.platformDispatcher.platformBrightness);
    return MaterialApp(
      title: 'UstaadAssist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      // Rebuilds on every login and logout, so no screen has to navigate for it.
      home: StreamBuilder(
        stream: AuthService.changes,
        builder: (context, _) => AuthService.isLoggedIn ? const MainShell() : const WelcomeScreen(),
      ),
    );
  }
}
