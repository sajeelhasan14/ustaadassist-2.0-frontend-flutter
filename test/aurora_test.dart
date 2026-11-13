import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ustaad_assist/core/theme/app_colors.dart';
import 'package:ustaad_assist/core/theme/appearance.dart';
import 'package:ustaad_assist/features/attendance/data/attendance_api.dart';
import 'package:ustaad_assist/features/attendance/screens/take_attendance_screen.dart';
import 'package:ustaad_assist/features/courses/screens/course_screen.dart';
import 'package:ustaad_assist/features/home/screens/main_shell.dart';
import 'package:ustaad_assist/features/papers/screens/paper_screen.dart';

import 'support/fake_backend.dart';

/// The Aurora Glass pieces: the glass menu's safe delete, the Appearance
/// setting, the dock, course colours, light mode and the reward message.
void main() {
  const classRef = ClassRef(sectionId: 's1', date: today, startTime: '09:00', title: 'Database Systems');
  const me = {'teacher': {'fullName': 'Sana Ahmed', 'minAttendance': 75}};

  setUp(() {
    // Stands in for the phone's storage, so Appearance.set can save.
    SharedPreferences.setMockInitialValues({});
    Appearance.choice.value = Appearance.system;
  });

  testWidgets('Delete in a glass menu needs a second tap', (tester) async {
    final backend = FakeBackend()..overrides['DELETE /questions/q1'] = {};
    await show(tester, PaperScreen(course: course, assessmentId: 'a1'));
    await tester.tap(find.byTooltip('Question options').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Tap again to delete'), findsOneWidget);
    expect(backend.sent('DELETE', '/questions/q1'), isEmpty); // nothing deleted yet

    await tester.tap(find.text('Tap again to delete'));
    await tester.pumpAndSettle();
    expect(backend.sent('DELETE', '/questions/q1'), hasLength(1));
  });

  testWidgets('tapping outside a glass menu closes it without doing anything', (tester) async {
    final backend = FakeBackend();
    await show(tester, PaperScreen(course: course, assessmentId: 'a1'));
    await tester.tap(find.byTooltip('Question options').first);
    await tester.pumpAndSettle();
    expect(find.text('Rewrite with AI'), findsOneWidget);

    await tester.tapAt(const Offset(10, 830));
    await tester.pumpAndSettle();
    expect(find.text('Rewrite with AI'), findsNothing);
    expect(backend.calls.where((call) => call.method != 'GET'), isEmpty);
  });

  testWidgets('the dock switches tabs and Me sets the appearance', (tester) async {
    FakeBackend()
      ..overrides['GET /me'] = me
      ..overrides['GET /courses'] = {'courses': []};
    await show(tester, const MainShell());
    expect(find.text('No courses yet.'), findsOneWidget);

    await tester.tap(find.byTooltip('Me'));
    await tester.pumpAndSettle();
    expect(find.text('APPEARANCE'), findsOneWidget);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(Appearance.choice.value, Appearance.light);
    expect((await SharedPreferences.getInstance()).getString('appearance'), 'light');
  });

  test('System follows the phone; Light and Dark stay put', () {
    Appearance.choice.value = Appearance.system;
    expect(Appearance.isLight(Brightness.light), isTrue);
    expect(Appearance.isLight(Brightness.dark), isFalse);
    Appearance.choice.value = Appearance.dark;
    expect(Appearance.isLight(Brightness.light), isFalse);
    Appearance.choice.value = Appearance.light;
    expect(Appearance.isLight(Brightness.dark), isTrue);
  });

  test('courses side by side get different colours, and keep them', () async {
    AppColors.courseColourIndex.clear();
    await Appearance.giveCourseColours(['a', 'b', 'c']);
    final first = [for (final id in ['a', 'b', 'c']) AppColors.courseColour(id)];
    expect(first.toSet(), hasLength(3));
    // A new course later on never moves the old ones.
    await Appearance.giveCourseColours(['a', 'b', 'c', 'd']);
    expect([for (final id in ['a', 'b', 'c']) AppColors.courseColour(id)], first);
    // And it's remembered on the phone for next time.
    expect((await SharedPreferences.getInstance()).getStringList('courseColours'), hasLength(4));
  });

  test('a course keeps its colour, and green words are deeper in light mode', () {
    expect(AppColors.courseColour('c1'), AppColors.courseColour('c1'));
    AppColors.isLight = true;
    expect(AppColors.greenText, const Color(0xFF00803F));
    expect(AppColors.green, const Color(0xFF00E676)); // the fill never changes
    AppColors.isLight = false;
    expect(AppColors.greenText, const Color(0xFF00E676));
  });

  testWidgets('the course bento shows the numbers in light mode too', (tester) async {
    for (final light in [false, true]) {
      AppColors.isLight = light;
      addTearDown(() => AppColors.isLight = false);
      FakeBackend();
      await show(tester, CourseScreen(course: course));
      expect(tester.takeException(), isNull);
      expect(find.text('3 classes left'), findsOneWidget);
      expect(find.text('Next · Today 09:00 · Normalization'), findsOneWidget);
      expect(find.text('of 4 topics taught'), findsOneWidget);
      expect(find.text('Syllabus'), findsOneWidget);
    }
  });

  testWidgets('saving attendance celebrates, with Undo only for a class marked before', (tester) async {
    FakeBackend();
    // Opened on top of another screen, like in the app, so the message has a
    // screen to show on once attendance closes.
    await show(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TakeAttendanceScreen(classRef: classRef))),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit attendance'));
    await tester.tap(find.text('Submit attendance'));
    await tester.pumpAndSettle();
    expect(find.text('Attendance saved · 3 present'), findsOneWidget);
    expect(find.text('Undo'), findsNothing); // a first save can't be un-marked
  });
}
