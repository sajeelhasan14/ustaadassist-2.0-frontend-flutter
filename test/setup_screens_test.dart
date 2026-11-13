import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustaad_assist/core/theme/app_theme.dart';
import 'package:ustaad_assist/features/courses/data/courses_api.dart';
import 'package:ustaad_assist/features/setup/data/setup_api.dart';
import 'package:ustaad_assist/features/setup/screens/setup_basics_screen.dart';
import 'package:ustaad_assist/features/setup/screens/setup_topics_screen.dart';

Future<void> show(WidgetTester tester, Widget screen, {double width = 390, double height = 844}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.current, home: screen));
  await tester.pump();
}

SetupProgress progress() => SetupProgress(
      course: Course.fromJson(const {'id': 'c1', 'code': 'CS-301', 'title': 'Database Systems'}),
      sectionId: 's1',
      semesterId: 'm1',
    );

void main() {
  group('step 1', () {
    testWidgets('asks for the name before anything is sent', (tester) async {
      await show(tester, const SetupBasicsScreen());
      await tester.tap(find.text('Next: add topics'));
      await tester.pump();
      expect(find.text('Enter the course name and code.'), findsOneWidget);
    });

    testWidgets('asks for the dates next', (tester) async {
      await show(tester, const SetupBasicsScreen());
      await tester.enterText(find.byType(TextField).at(0), 'Database Systems');
      await tester.enterText(find.byType(TextField).at(1), 'CS-301');
      await tester.tap(find.text('Next: add topics'));
      await tester.pump();
      expect(find.text('Choose when the semester starts and ends.'), findsOneWidget);
    });

    testWidgets('choosing a day adds its time row, and tapping again removes it', (tester) async {
      await show(tester, const SetupBasicsScreen());
      await tester.tap(find.bySemanticsLabel('Monday'));
      await tester.pump();
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);

      // The chip's letter, because the time row now also says "Monday".
      await tester.tap(find.text('M'));
      await tester.pump();
      expect(find.text('09:00'), findsNothing);
    });

    testWidgets('a second day copies the first time, in week order', (tester) async {
      await show(tester, const SetupBasicsScreen());
      await tester.tap(find.bySemanticsLabel('Wednesday'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Monday'));
      await tester.pump();
      expect(find.text('09:00'), findsNWidgets(2));
      expect(tester.getTopLeft(find.text('Monday')).dy, lessThan(tester.getTopLeft(find.text('Wednesday')).dy));
    });

    testWidgets('fits a small phone with every day chosen', (tester) async {
      await show(tester, const SetupBasicsScreen(), width: 320, height: 568);
      for (final day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']) {
        await tester.tap(find.bySemanticsLabel(day), warnIfMissed: false);
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('step 2', () {
    Future<void> paste(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
    }

    testWidgets('numbers, bullets and blank lines are cleaned away', (tester) async {
      await show(tester, SetupTopicsScreen(progress: progress()));
      await paste(tester, '1. Intro\n2) Joins\n\n- Keys\n• Views\n   \n* Locks\nPlain');
      final count = tester.widget<Text>(find.text('6'));
      expect(count.data, '6');
    });

    testWidgets('a topic that starts with a number word keeps it', (tester) async {
      await show(tester, SetupTopicsScreen(progress: progress()));
      await paste(tester, '3NF and BCNF\n2-phase locking');
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('empty can be skipped during setup', (tester) async {
      await show(tester, SetupTopicsScreen(progress: progress()));
      expect(find.text('Skip for now'), findsOneWidget);
      await paste(tester, 'Intro');
      expect(find.text('Next: holidays'), findsOneWidget);
    });

    testWidgets('adding to an existing course needs at least one topic', (tester) async {
      await show(tester, SetupTopicsScreen(progress: progress(), standalone: true));
      // The main button; the topics step also has a "Photo of outline" button now.
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save topics'));
      expect(button.onPressed, isNull);
    });
  });
}
