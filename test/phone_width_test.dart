import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustaad_assist/core/theme/app_theme.dart';
import 'package:ustaad_assist/features/auth/screens/sign_in_screen.dart';
import 'package:ustaad_assist/features/auth/screens/sign_up_screen.dart';
import 'package:ustaad_assist/features/auth/screens/welcome_screen.dart';

/// Flutter reports a layout that doesn't fit as a test failure, so these catch
/// anything running off the edge of a small phone.
void main() {
  for (final (width, height) in [(390.0, 844.0), (320.0, 568.0)]) {
    Future<void> show(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.current, home: screen));
      await tester.pump();
    }

    testWidgets('Welcome fits at $width wide', (tester) async {
      await show(tester, const WelcomeScreen());
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('Get started')).right, lessThanOrEqualTo(width));
    });

    testWidgets('Sign in fits at $width wide', (tester) async {
      await show(tester, const SignInScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sign up fits at $width wide', (tester) async {
      await show(tester, const SignUpScreen());
      expect(tester.takeException(), isNull);
    });
  }
}
