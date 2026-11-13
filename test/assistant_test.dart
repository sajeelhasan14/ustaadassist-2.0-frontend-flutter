import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustaad_assist/features/assistant/screens/assistant_sheet.dart';
import 'package:ustaad_assist/features/attendance/data/attendance_api.dart';
import 'package:ustaad_assist/features/attendance/screens/take_attendance_screen.dart';
import 'package:ustaad_assist/features/courses/data/courses_api.dart';
import 'package:ustaad_assist/features/home/data/home_api.dart';
import 'package:ustaad_assist/features/home/screens/home_screen.dart';
import 'package:ustaad_assist/features/marks/screens/assessments_screen.dart';
import 'package:ustaad_assist/features/courses/screens/course_settings_screen.dart';

import 'support/fake_backend.dart';

const proposal = {
  'title': 'Cancel class',
  'detail': 'SE-454 · Section A · Tue 10 Nov · 09:00',
  'method': 'POST',
  'path': '/sections/s1/sessions',
  'body': {'date': '2026-11-10', 'startTime': '09:00', 'status': 'cancelled'},
};

Map<String, dynamic> reply(String text, {List<Object> proposals = const [], List<Object> stats = const []}) => {
      'reply': text,
      'toolsUsed': <String>[],
      'proposals': proposals,
      'stats': stats,
    };

Future<void> ask(WidgetTester tester, String question) async {
  await tester.enterText(find.byType(TextField), question);
  await tester.tap(find.byTooltip('Send'));
  await tester.pumpAndSettle();
}

Widget sheet({VoidCallback? onChanged}) => Scaffold(body: AssistantSheet(courseId: 'c1', sectionId: 's1', onChanged: onChanged));

void main() {
  group('assistant chat', () {
    testWidgets('sends the question with the open course, and shows the reply and its numbers', (tester) async {
      final backend = FakeBackend();
      backend.overrides['POST /assistant'] = reply('You are 2 classes behind plan.', stats: [
        {'value': '14/20', 'label': 'TOPICS DONE', 'tone': 'normal'},
        {'value': '2', 'label': 'BEHIND', 'tone': 'warning'},
      ]);
      await show(tester, sheet());
      await ask(tester, 'How far am I?');

      expect(backend.sent('POST', '/assistant').single.body, {'message': 'How far am I?', 'history': [], 'courseId': 'c1', 'sectionId': 's1'});
      expect(find.text('How far am I?'), findsOneWidget);
      expect(find.text('You are 2 classes behind plan.'), findsOneWidget);
      expect(find.text('14/20'), findsOneWidget);
      expect(find.text('BEHIND'), findsOneWidget);
    });

    testWidgets('home sends no course, and a suggestion asks in one tap', (tester) async {
      final backend = FakeBackend();
      backend.overrides['POST /assistant'] = reply('Two classes.');
      await show(tester, const Scaffold(body: AssistantSheet()));
      await tester.tap(find.text('What classes do I have today?'));
      await tester.pumpAndSettle();

      expect(backend.sent('POST', '/assistant').single.body, {'message': 'What classes do I have today?', 'history': []});
    });

    testWidgets('a follow-up carries the conversation so far', (tester) async {
      final backend = FakeBackend();
      backend.overrides['POST /assistant'] = reply('Omar is short.');
      await show(tester, sheet());
      await ask(tester, 'Who is short?');
      await ask(tester, 'And his marks?');

      expect(backend.sent('POST', '/assistant').last.body['history'], [
        {'role': 'user', 'text': 'Who is short?'},
        {'role': 'assistant', 'text': 'Omar is short.'},
      ]);
    });

    testWidgets('a failure explains itself, and Try again asks the same thing without repeating the bubble', (tester) async {
      final backend = FakeBackend();
      backend.fail('POST /assistant', 502, 'ai_failed', "The assistant isn't available right now. Please try again.");
      await show(tester, sheet());
      await ask(tester, 'Who is short?');

      expect(find.textContaining("isn't available"), findsOneWidget);
      backend.overrides['POST /assistant'] = reply('Omar is short.');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Omar is short.'), findsOneWidget);
      expect(find.text('Who is short?'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(backend.sent('POST', '/assistant').last.body['history'], isEmpty);
    });

    testWidgets('voice that isn\'t available says so and typing still works', (tester) async {
      FakeBackend();
      await show(tester, sheet());
      await tester.tap(find.byTooltip('Speak'));
      // The plugin answers on a real clock, which a widget test doesn't move by itself.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();

      expect(find.textContaining('You can type instead'), findsOneWidget);
      expect(find.byTooltip('Send'), findsOneWidget);
    });
  });

  group('assistant changes', () {
    testWidgets('nothing is sent until Confirm, then exactly the proposed request, once', (tester) async {
      final backend = FakeBackend();
      backend.overrides['POST /assistant'] = reply('Ready to confirm.', proposals: [proposal]);
      backend.overrides['POST /sections/s1/sessions'] = {'session': {}};
      var changed = 0;
      await show(tester, sheet(onChanged: () => changed++));
      await ask(tester, 'Cancel Tuesday');

      expect(find.text('SE-454 · Section A · Tue 10 Nov · 09:00'), findsOneWidget);
      expect(backend.sent('POST', '/sections/s1/sessions'), isEmpty);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(backend.sent('POST', '/sections/s1/sessions').single.body, {'date': '2026-11-10', 'startTime': '09:00', 'status': 'cancelled'});
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Confirm'), findsNothing);
      expect(changed, 1);
    });

    testWidgets('Not now sends nothing', (tester) async {
      final backend = FakeBackend();
      backend.overrides['POST /assistant'] = reply('Ready to confirm.', proposals: [proposal]);
      await show(tester, sheet());
      await ask(tester, 'Cancel Tuesday');
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(backend.sent('POST', '/sections/s1/sessions'), isEmpty);
      expect(find.text('Left as it was'), findsOneWidget);
    });

    testWidgets('a refused change shows why and can be tried again', (tester) async {
      final backend = FakeBackend();
      backend.overrides['POST /assistant'] = reply('Ready to confirm.', proposals: [proposal]);
      backend.fail('POST /sections/s1/sessions', 400, 'bad', 'That class has already been held.');
      var changed = 0;
      await show(tester, sheet(onChanged: () => changed++));
      await ask(tester, 'Cancel Tuesday');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('That class has already been held.'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(changed, 0);
    });

    testWidgets('a PATCH proposal is sent as a PATCH', (tester) async {
      final backend = FakeBackend();
      backend.overrides['POST /assistant'] = reply('Ready.', proposals: [
        {'title': 'Change attendance line', 'detail': 'x', 'method': 'PATCH', 'path': '/me', 'body': {'minAttendance': 80}},
      ]);
      backend.overrides['PATCH /me'] = {'teacher': {}};
      await show(tester, sheet());
      await ask(tester, 'Make it 80');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(backend.sent('PATCH', '/me').single.body, {'minAttendance': 80});
    });
  });

  group('attendance warning', () {
    const classRef = ClassRef(sectionId: 's1', date: today, startTime: '09:00', title: 'Database Systems');

    testWidgets('warns about a student marked absent who is below the line, then leaves', (tester) async {
      FakeBackend();
      await show(tester, const TakeAttendanceScreen(classRef: classRef));
      await tester.tap(find.text('NASIR AKHTAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit attendance'));
      await tester.pumpAndSettle();

      expect(find.text('1 student below 75%'), findsOneWidget);
      expect(find.text('NASIR AKHTAR · 50%'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('1 student below 75%'), findsNothing);
    });

    testWidgets('says nothing when nobody absent today is short', (tester) async {
      FakeBackend();
      await show(tester, const TakeAttendanceScreen(classRef: classRef));
      await tester.tap(find.text('Submit attendance'));
      await tester.pumpAndSettle();

      expect(find.textContaining('below 75%'), findsNothing);
    });

    testWidgets('stays quiet this early in the semester, when one absence would trip it', (tester) async {
      final backend = FakeBackend();
      backend.overrides['GET /sections/s1/attendance'] = {
        'held': 2,
        'min': 75,
        'average': 50,
        'students': [
          {'id': 'st2', 'rollNumber': 'EB2', 'fullName': 'NASIR AKHTAR', 'present': 1, 'marked': 2, 'percentage': 50, 'shortage': true},
        ],
      };
      await show(tester, const TakeAttendanceScreen(classRef: classRef));
      await tester.tap(find.text('NASIR AKHTAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit attendance'));
      await tester.pumpAndSettle();

      expect(find.textContaining('below 75%'), findsNothing);
    });

    testWidgets('a report that fails to load doesn\'t get in the way of saved attendance', (tester) async {
      final backend = FakeBackend();
      backend.fail('GET /sections/s1/attendance', 500, 'oops', 'Nope.');
      await show(tester, const TakeAttendanceScreen(classRef: classRef));
      await tester.tap(find.text('NASIR AKHTAR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit attendance'));
      await tester.pumpAndSettle();

      expect(backend.sent('PUT', '/sessions/x9/attendance'), hasLength(1));
      expect(find.text('Nope.'), findsNothing);
    });
  });

  group('home', () {
    HomeData data({List<AttendanceAlert> alerts = const [], List<ComingUp> comingUp = const []}) => HomeData(
          teacherName: 'Test Teacher',
          date: today,
          offDay: null,
          classes: const [],
          courses: const [],
          alerts: alerts,
          comingUp: comingUp,
        );

    testWidgets('shows the warning and dated assessments', (tester) async {
      FakeBackend();
      await show(
        tester,
        Scaffold(
          body: HomeView(
            onOpen: (_) {},
            data: data(
              alerts: [
                AttendanceAlert.fromJson({'sectionId': 's1', 'sectionName': 'A', 'courseId': 'c1', 'courseCode': 'SE-204', 'below': 2, 'min': 75}),
              ],
              comingUp: [
                ComingUp.fromJson({'name': 'Presentation 1', 'date': '2026-11-20', 'courseId': 'c1', 'courseCode': 'SE-204'}),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ATTENDANCE WARNING'), findsOneWidget);
      expect(find.text('2 students below 75%'), findsOneWidget);
      expect(find.text('SE-204 · Section A'), findsOneWidget);
      expect(find.text('COMING UP'), findsOneWidget);
      expect(find.text('Presentation 1'), findsOneWidget);
      expect(find.text('20 NOV'), findsOneWidget);
    });

    testWidgets('with no dates and nobody short, neither part appears at all', (tester) async {
      FakeBackend();
      await show(tester, Scaffold(body: HomeView(onOpen: (_) {}, data: data())));

      expect(find.text('ATTENDANCE WARNING'), findsNothing);
      expect(find.text('COMING UP'), findsNothing);
    });
  });

  // Each course has its own line, changed in that course's settings (decision of 2026-11-09).
  group('attendance line', () {
    final course = Course.fromJson({'id': 'c1', 'semesterId': 'm1', 'code': 'CS-301', 'title': 'Database Systems', 'minAttendance': 75});
    final section = Section.fromJson({'id': 's1', 'name': 'A', 'studentCount': 3});
    final settings = CourseSettingsScreen(course: course, section: section, onCourseChanged: (_) {});

    Future<void> changeTo(WidgetTester tester, String value) async {
      await tester.ensureVisible(find.text('Attendance line'));
      await tester.tap(find.text('Attendance line'));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), value);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the course line and changes it for this course only', (tester) async {
      final backend = FakeBackend();
      backend.overrides['PATCH /courses/c1'] = {'course': {'id': 'c1', 'code': 'CS-301', 'title': 'Database Systems', 'minAttendance': 80}};
      await show(tester, settings);

      expect(find.text('75%'), findsOneWidget);
      await changeTo(tester, '80');

      expect(backend.sent('PATCH', '/courses/c1').single.body, {'minAttendance': 80});
      expect(find.text('80%'), findsOneWidget);
      expect(backend.sent('PATCH', '/me'), isEmpty); // no longer one line for all courses
    });

    testWidgets('a refused value keeps the old line and says why', (tester) async {
      final backend = FakeBackend();
      backend.fail('PATCH /courses/c1', 400, 'bad', 'Must be 100 or less.');
      await show(tester, settings);
      await changeTo(tester, '150');

      expect(find.text('Must be 100 or less.'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });
  });

  group('assessment dates', () {
    final course = Course.fromJson({'id': 'c1', 'code': 'CS-301', 'title': 'Database Systems'});
    final section = Section.fromJson({'id': 's1', 'name': 'A', 'studentCount': 3});

    testWidgets('an assessment can be added with no date at all', (tester) async {
      final backend = FakeBackend();
      await show(tester, AssessmentsScreen(course: course, section: section));
      await tester.ensureVisible(find.text('Add assessment'));
      await tester.tap(find.text('Add assessment'));
      await tester.pumpAndSettle();
      expect(find.text('Optional'), findsOneWidget);

      await tester.tap(find.text('Presentation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final body = backend.sent('POST', '/courses/c1/assessments').single.body as Map;
      expect(body.containsKey('date'), isFalse);
    });

    testWidgets('a picked date is sent', (tester) async {
      final backend = FakeBackend();
      await show(tester, AssessmentsScreen(course: course, section: section));
      await tester.ensureVisible(find.text('Add assessment'));
      await tester.tap(find.text('Add assessment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Presentation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final body = backend.sent('POST', '/courses/c1/assessments').single.body as Map;
      expect(body['date'], endsWith('-15'));
    });
  });
}
