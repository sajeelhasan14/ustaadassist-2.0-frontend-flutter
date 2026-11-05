import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustaad_assist/core/api/api_client.dart';
import 'package:ustaad_assist/features/attendance/data/attendance_api.dart';
import 'package:ustaad_assist/features/attendance/screens/classes_screen.dart';
import 'package:ustaad_assist/features/attendance/screens/take_attendance_screen.dart';
import 'package:ustaad_assist/features/courses/data/courses_api.dart';
import 'package:ustaad_assist/features/dashboard/screens/dashboard_screen.dart';
import 'package:ustaad_assist/features/marks/screens/assessments_screen.dart';
import 'package:ustaad_assist/features/marks/screens/marks_entry_screen.dart';
import 'package:ustaad_assist/features/papers/screens/generate_paper_screen.dart';
import 'package:ustaad_assist/features/papers/screens/paper_screen.dart';
import 'package:ustaad_assist/features/papers/screens/question_edit_screen.dart';
import 'package:ustaad_assist/features/plan/data/plan_api.dart';
import 'package:ustaad_assist/features/plan/screens/plan_screen.dart';
import 'package:ustaad_assist/features/results/screens/results_screen.dart';
import 'package:ustaad_assist/features/students/data/students_api.dart';
import 'package:ustaad_assist/features/students/screens/review_list_screen.dart';
import 'package:ustaad_assist/shared/widgets/prompts.dart';

import 'support/fake_backend.dart';

const classRef = ClassRef(sectionId: 's1', date: today, startTime: '09:00', title: 'Database Systems');

/// Reaches a button or row that may be below the fold, then taps it.
Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  group('attendance', () {
    testWidgets('creates the class, pre-fills the planned topic, and sends only the absent', (tester) async {
      final backend = FakeBackend();
      await show(tester, const TakeAttendanceScreen(classRef: classRef));

      expect(backend.sent('POST', '/sections/s1/sessions').single.body, {'date': today, 'startTime': '09:00'});
      expect(find.text('Normalization'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // everyone starts present

      await tester.tap(find.text('NASIR AKHTAR'));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);

      await tapText(tester, 'Submit attendance');
      expect(backend.sent('PUT', '/sessions/x9/attendance').single.body, {
        'absent': ['st2'],
        'topicIds': ['t2'],
      });
    });

    testWidgets('a failed save shows why and keeps what was tapped', (tester) async {
      final backend = FakeBackend()..fail('PUT /sessions/x9/attendance', 400, 'future_class', "This class hasn't happened yet.");
      await show(tester, const TakeAttendanceScreen(classRef: classRef));
      await tester.tap(find.text('ABDUL GHANI'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Submit attendance');

      expect(find.text("This class hasn't happened yet."), findsOneWidget);
      expect(find.text('Submit attendance'), findsOneWidget);
      expect(backend.sent('PUT', '/sessions/x9/attendance').single.body['absent'], ['st1']);
    });

    testWidgets('a class already marked starts from its saved absentees and topics', (tester) async {
      final backend = FakeBackend();
      backend.overrides['GET /sessions/x9/attendance'] = {
        'marked': true,
        'topics': [
          {'id': 't1', 'title': 'Relational Model'},
        ],
        'students': [
          {'id': 'st1', 'rollNumber': 'E1', 'fullName': 'ABDUL GHANI', 'present': false},
          {'id': 'st2', 'rollNumber': 'E2', 'fullName': 'NASIR AKHTAR', 'present': true},
        ],
      };
      await show(tester, const TakeAttendanceScreen(classRef: classRef));
      expect(find.text('1 absent'), findsOneWidget);
      expect(find.text('Relational Model'), findsOneWidget);
      expect(find.text('Update attendance'), findsOneWidget);
    });

    testWidgets('the class list puts unmarked classes first and can cancel and restore', (tester) async {
      final backend = FakeBackend();
      await show(tester, ClassesScreen(course: course, section: section));
      expect(find.text('TO MARK'), findsOneWidget);
      expect(find.text('To mark'), findsNWidgets(2)); // the missed class and today's

      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel class').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel class'));
      await tester.pumpAndSettle();
      expect(backend.sent('POST', '/sections/s1/sessions').single.body, {'date': '2026-11-02', 'startTime': '09:00', 'status': 'cancelled'});
    });
  });

  group('marks entry', () {
    Future<FakeBackend> open(WidgetTester tester) async {
      final backend = FakeBackend();
      await show(tester, MarksEntryScreen(assessmentId: 'a1', section: section));
      return backend;
    }

    Future<void> press(WidgetTester tester, String keys) async {
      for (final key in keys.split('')) {
        await tester.tap(find.widgetWithText(InkWell, key).last);
        await tester.pump();
      }
    }

    testWidgets('picks up at the first student with no mark', (tester) async {
      await open(tester);
      expect(find.text('NASIR AKHTAR'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('a decimal mark is saved and the next student is ready at once', (tester) async {
      final backend = await open(tester);
      await press(tester, '8.5');
      await tester.tap(find.text('Save and next'));
      await tester.pumpAndSettle();

      expect(find.text('SANA'), findsOneWidget);
      expect(backend.sent('PUT', '/assessments/a1/marks').single.body, {
        'marks': [
          {'studentId': 'st2', 'marks': 8.5},
        ],
      });
    });

    testWidgets('a mark above the maximum can\'t be saved', (tester) async {
      final backend = await open(tester);
      await press(tester, '11');
      expect(find.text('Too high'), findsOneWidget);
      await tester.tap(find.text('Save and next'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(backend.sent('PUT', '/assessments/a1/marks'), isEmpty);
    });

    testWidgets('Absent clears an entered mark instead of saving a zero', (tester) async {
      final backend = await open(tester);
      await tester.tap(find.text('7.5')); // back to the first student
      await tester.pumpAndSettle();
      await tester.tap(find.text('Absent'));
      await tester.pumpAndSettle();
      expect(backend.sent('PUT', '/assessments/a1/marks').single.body['marks'], [
        {'studentId': 'st1', 'marks': null},
      ]);
    });

    testWidgets('a failed save loses nothing: the mark goes again with the next one', (tester) async {
      final backend = FakeBackend()..fail('PUT /assessments/a1/marks', 500, 'server_error', 'The server had a problem.');
      await show(tester, MarksEntryScreen(assessmentId: 'a1', section: section));
      await press(tester, '8');
      await tester.tap(find.text('Save and next'));
      await tester.pumpAndSettle();
      expect(find.text('The server had a problem.'), findsOneWidget);

      backend.overrides.remove('PUT /assessments/a1/marks');
      await press(tester, '9');
      await tester.tap(find.text('Save and finish'));
      await tester.pumpAndSettle();

      expect(backend.sent('PUT', '/assessments/a1/marks').last.body['marks'], [
        {'studentId': 'st2', 'marks': 8},
        {'studentId': 'st3', 'marks': 9},
      ]);
    });

    testWidgets('leaving with unsaved marks asks first', (tester) async {
      FakeBackend().fail('PUT /assessments/a1/marks', 500, 'server_error', 'The server had a problem.');
      await show(tester, Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MarksEntryScreen(assessmentId: 'a1', section: section))),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await press(tester, '8');
      await tester.tap(find.text('Save and next'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text("1 marks aren't saved"), findsOneWidget);
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(find.text('SANA'), findsOneWidget);
    });
  });

  group('assessments', () {
    testWidgets('a suggestion picks the next free name and the marks default to what is left', (tester) async {
      final backend = FakeBackend();
      await show(tester, AssessmentsScreen(course: course, section: section));
      await tapText(tester, 'Add assessment');
      await tester.tap(find.text('Quiz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(backend.sent('POST', '/courses/c1/assessments').single.body, {'name': 'Quiz 2', 'maxMarks': 40, 'isLab': false});
    });
  });

  group('class list review', () {
    ExtractedList list() => ExtractedList.fromJson({
          'warnings': ['The file says section B.'],
          'students': [
            {'row': 1, 'rollNumber': 'E1', 'fullName': 'ABDUL GHANI', 'fatherName': 'AFZAL', 'status': 'new', 'message': null},
            {'row': 2, 'rollNumber': '', 'fullName': 'NASIR AKHTAR', 'fatherName': null, 'status': 'missing_data', 'message': 'No seat number.'},
            {'row': 3, 'rollNumber': 'E3', 'fullName': 'SANA', 'fatherName': null, 'status': 'already_enrolled', 'message': 'Already in this section.'},
          ],
        });

    testWidgets('confirm stays off until the flagged row is fixed, and skipped rows aren\'t sent', (tester) async {
      final backend = FakeBackend();
      await show(tester, ReviewListScreen(section: section, list: list()));

      expect(find.text('1 row needs you'), findsOneWidget);
      expect(find.text('The file says section B.'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm 2 students')).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Seat number'), 'E2');
      await tester.pumpAndSettle();
      await tapText(tester, 'Confirm 2 students');

      expect(backend.sent('POST', '/sections/s1/import').single.body, {
        'students': [
          {'rollNumber': 'E1', 'fullName': 'ABDUL GHANI', 'fatherName': 'AFZAL'},
          {'rollNumber': 'E2', 'fullName': 'NASIR AKHTAR'},
        ],
      });
    });

    testWidgets('removing the flagged row also clears the way', (tester) async {
      FakeBackend();
      await show(tester, ReviewListScreen(section: section, list: list()));
      await tester.tap(find.byTooltip('Remove this row').at(1));
      await tester.pumpAndSettle();
      expect(find.text('All clear'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm 1 student')).onPressed, isNotNull);
    });
  });

  group('question papers', () {
    testWidgets('shows drafts, attempt-any and parts, and approves everything in one tap', (tester) async {
      final backend = FakeBackend();
      await show(tester, PaperScreen(course: course, assessmentId: 'a1'));
      expect(find.text('1 DRAFT TO CHECK'.toUpperCase()), findsOneWidget);
      expect(find.text('2 / 10'), findsOneWidget);
      expect(find.textContaining('Attempt any 2'), findsOneWidget);
      expect(find.text('(a) Define 1NF. [4]'), findsOneWidget);
      expect(find.text('B. 2NF'), findsOneWidget);

      await tester.tap(find.text('Approve all'));
      await tester.pumpAndSettle();
      expect(backend.sent('PATCH', '/assessments/a1/questions').single.body, {'status': 'approved'});
    });

    testWidgets('moving a question sends the whole new order', (tester) async {
      final backend = FakeBackend();
      await show(tester, PaperScreen(course: course, assessmentId: 'a1'));
      await tester.tap(find.byTooltip('Question options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move down'));
      await tester.pumpAndSettle();
      expect(backend.sent('PUT', '/assessments/a1/questions').single.body, {
        'sections': [
          {'id': 'p1', 'questionIds': ['q2', 'q1']},
        ],
      });
    });

    testWidgets('generating sends the instructions and marks per topic', (tester) async {
      final backend = FakeBackend();
      await show(tester, GeneratePaperScreen(course: course, assessmentId: 'a2', paperName: 'Lab Work'));
      await tester.tap(find.text('MCQs only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Normalization'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Marks'), '15');
      await tester.tap(find.text('Write the paper'));
      await tester.pumpAndSettle();
      expect(backend.sent('POST', '/assessments/a2/questions/generate').single.body, {
        'instructions': 'MCQs only.',
        'topics': [
          {'id': 't2', 'marks': 15},
        ],
      });
    });

    testWidgets('a busy AI shows the reason and offers another go', (tester) async {
      FakeBackend().fail('POST /assessments/a2/questions/generate', 502, 'ai_failed', 'Couldn\'t write the paper right now.');
      await show(tester, GeneratePaperScreen(course: course, assessmentId: 'a2', paperName: 'Lab Work'));
      await tester.tap(find.text('Write the paper'));
      await tester.pumpAndSettle();
      expect(find.text('Couldn\'t write the paper right now.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('multiple choice needs two options before anything is sent', (tester) async {
      final backend = FakeBackend();
      await show(tester, const QuestionEditScreen(assessmentId: 'a1'));
      await tester.tap(find.text('mcq'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Question'), 'Which one?');
      await tester.enterText(find.widgetWithText(TextField, 'Marks'), '2');
      await tester.tap(find.text('Save question'));
      await tester.pumpAndSettle();
      expect(find.text('Add at least 2 options.'), findsOneWidget);
      expect(backend.calls, isEmpty);

      await tester.enterText(find.widgetWithText(TextField, 'A'), 'One');
      await tester.enterText(find.widgetWithText(TextField, 'B'), 'Two');
      await tester.tap(find.text('Save question'));
      await tester.pumpAndSettle();
      expect(backend.sent('POST', '/assessments/a1/questions').single.body, {
        'type': 'mcq',
        'text': 'Which one?',
        'difficulty': 'medium',
        'options': ['One', 'Two'],
        'marks': 2,
      });
    });
  });

  group('results and dashboard', () {
    testWidgets('results show the backend\'s numbers and warn while marks are missing', (tester) async {
      FakeBackend();
      await show(tester, ResultsScreen(course: course, section: section));
      expect(find.text('1 passed'), findsOneWidget);
      expect(find.text('1 NOT FINAL'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('B+'), 200);
      expect(find.text('B+'), findsOneWidget);
      expect(find.text('Fail in Th. & Pr. · 1 marks missing'), findsOneWidget);
      expect(find.text('Abs'), findsOneWidget);
    });

    testWidgets('the dashboard shows real averages and a dash where there are no marks', (tester) async {
      FakeBackend();
      await show(tester, DashboardScreen(course: course, section: section));
      expect(find.text('On track'), findsOneWidget);
      expect(find.text('1/4'), findsOneWidget);
      expect(find.text('83%'), findsOneWidget);
      expect(find.text('73%'), findsOneWidget); // 72.5 rounded for display
      expect(find.text('–'), findsOneWidget);
      expect(find.text('1 past class has no attendance yet.'), findsOneWidget);
    });
  });

  group('plan', () {
    SectionPlan plan(int short) => SectionPlan.fromJson(calendar(short: short));

    test('shortening takes from the last topics and leaves each at least one class', () {
      final cuts = PlanApi.shortenSuggestion(plan(4));
      expect(cuts.map((cut) => (cut.topic.id, cut.newClasses)), [('t4', 1), ('t3', 1)]);
    });

    test('shortening never touches a topic with one class left', () {
      expect(PlanApi.shortenSuggestion(plan(1)).single.topic.id, 't4');
      expect(PlanApi.shortenSuggestion(plan(9)).any((cut) => cut.topic.id == 't2'), isFalse);
    });

    test('dropping only offers topics nobody has started, last first', () {
      expect(PlanApi.dropSuggestion(plan(3)).map((topic) => topic.id), ['t4', 't3']);
      expect(PlanApi.dropSuggestion(plan(99)).map((topic) => topic.id), ['t4', 't3']);
    });

    test('classes are grouped by the Monday of their week', () {
      final weeks = PlanWeek.from(plan(0).sessions);
      expect(weeks.map((week) => week.monday), ['2026-10-26', '2026-11-02', '2026-11-09']);
      expect(weeks[1].contains(today), isTrue);
      expect(weeks[2].contains(today), isFalse);
    });

    testWidgets('the plan opens on the current week', (tester) async {
      FakeBackend();
      await show(tester, PlanScreen(course: course, section: section));
      expect(find.text('WEEK 2 · FROM 02 NOV'), findsOneWidget);
      expect(find.text('Take'), findsNWidgets(2));
      expect(find.text('Iqbal Day'), findsOneWidget);
    });
  });

  group('api client', () {
    test('an upload says what kind of file it is, because the backend checks', () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://test',
        token: () => 'abc',
        client: MockClient((request) async {
          seen = request;
          return http.Response('{"ok":true}', 200);
        }),
      );
      await client.upload('/files', [UploadFile(field: 'file', name: 'Slides.PPTX', bytes: Uint8List.fromList([1, 2]))], fields: {'topicId': 't1'});
      expect(seen.headers['authorization'], 'Bearer abc');
      expect(seen.body, contains('application/vnd.openxmlformats-officedocument.presentationml.presentation'));
      expect(seen.body, contains('name="topicId"'));
    });

    test('a download returns the file, and a failed one reads as a normal error', () async {
      final client = ApiClient(
        baseUrl: 'http://test',
        token: () => null,
        client: MockClient((request) async => request.url.path == '/ok'
            ? http.Response.bytes([37, 80, 68, 70], 200)
            : http.Response('{"error":{"code":"not_found","message":"Section not found."}}', 404)),
      );
      expect(await client.download('/ok'), [37, 80, 68, 70]);
      await expectLater(client.download('/no'), throwsA(predicate((error) => '$error' == 'Section not found.')));
    });

    test('data in an error is never shown as if it were a sentence', () async {
      final body = jsonEncode({
        'error': {
          'code': 'above_max',
          'message': 'Some marks are above the maximum.',
          'fields': {'studentIds': ['5f3a']},
        },
      });
      final client = ApiClient(baseUrl: 'http://test', token: () => null, client: MockClient((_) async => http.Response(body, 400)));
      await expectLater(client.get('/x'), throwsA(predicate((error) => '$error' == 'Some marks are above the maximum.')));
    });
  });

  test('marks print the way a teacher writes them', () {
    expect(markText(7.5), '7.5');
    expect(markText(10), '10');
    expect(markText(100), '100');
    expect(markText(0), '0');
    expect(markText(41.25), '41.25');
  });
}
