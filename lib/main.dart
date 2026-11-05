import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';

/// Starts the app. Login has to be ready before the first screen, so it can
/// tell whether the teacher is already signed in.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Config.isComplete) {
    runApp(const _MissingSettings());
    return;
  }
  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseAnonKey);
  runApp(const UstaadAssistApp());
}

/// Shown instead of a confusing crash if the app is started without its settings.
class _MissingSettings extends StatelessWidget {
  const _MissingSettings();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Settings are missing. Start the app with:\nflutter run --dart-define-from-file=dart_defines.json'),
          ),
        ),
      ),
    );
  }
}
