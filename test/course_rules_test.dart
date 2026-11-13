import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustaad_assist/core/api/api_client.dart';
import 'package:ustaad_assist/features/auth/screens/forgot_password_screen.dart';
import 'package:ustaad_assist/features/courses/data/courses_api.dart';
import 'package:ustaad_assist/features/courses/screens/grade_scale_screen.dart';
import 'package:ustaad_assist/features/setup/data/setup_api.dart';
import 'package:ustaad_assist/features/setup/screens/setup_holidays_screen.dart';
import 'package:ustaad_assist/features/students/data/students_api.dart';
import 'package:ustaad_assist/features/students/screens/student_details_screen.dart';

import 'support/fake_backend.dart';

/// The features finished on 2026-11-11: each course's own grade scale and holidays,
/// student details, topic import and forgot password.
void main() {
  final scaled = Course.fromJson({
    'id': 'c1',
    'semesterId': 'm1',
    'code': 'CS-301',
    'title': 'Database Systems',
    'defaultGradeScale': true,
    'gradeScale': [
      {'grade': 'A', 'min': 80},
      {'grade': 'B', 'min': 65},
      {'grade': 'C', 'min': 50},
    ],
  });

  group('grade scale', () {
    testWidgets('opens filled with the current scale and saves it highest first', (tester) async {
      final backend = FakeBackend()..overrides['PATCH /courses/c1'] = {'course': {'id': 'c1', 'code': 'CS-301', 'title': 'Database Systems'}};
      await show(tester, GradeScaleScreen(course: scaled));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);

      // Lower the pass mark to 45, then save.
      await tester.enterText(find.widgetWithText(TextField, '50'), '45');
      await tester.tap(find.text('Save grade scale'));
      await tester.pumpAndSettle();
      expect(backend.sent('PATCH', '/courses/c1').single.body, {
        'gradeScale': [
          {'grade': 'A', 'min': 80},
          {'grade': 'B', 'min': 65},
          {'grade': 'C', 'min': 45},
        ],
      });
    });

    testWidgets('two grades starting at the same % are caught before saving', (tester) async {
      final backend = FakeBackend();
      await show(tester, GradeScaleScreen(course: scaled));
      await tester.enterText(find.widgetWithText(TextField, '65'), '80');
      await tester.tap(find.text('Save grade scale'));
      await tester.pumpAndSettle();
      expect(find.text("Two grades can't start at the same %."), findsOneWidget);
      expect(backend.sent('PATCH', '/courses/c1'), isEmpty);
    });

    testWidgets('a changed scale can go back to the default', (tester) async {
      final custom = Course.fromJson({'id': 'c1', 'code': 'CS-301', 'title': 'Database Systems', 'defaultGradeScale': false, 'gradeScale': [{'grade': 'P', 'min': 50}]});
      final backend = FakeBackend()..overrides['PATCH /courses/c1'] = {'course': {'id': 'c1', 'code': 'CS-301', 'title': 'Database Systems'}};
      await show(tester, GradeScaleScreen(course: custom));
      await tester.ensureVisible(find.text('Use the default scale'));
      await tester.tap(find.text('Use the default scale'));
      await tester.pumpAndSettle();
      expect(backend.sent('PATCH', '/courses/c1').single.body, {'gradeScale': null});
    });
  });

  group('holidays per course', () {
    testWidgets('asks for this course only, and adds a holiday to it', (tester) async {
      final backend = FakeBackend()
        ..overrides['GET /off-days'] = {'offDays': []}
        ..overrides['POST /off-days'] = {'offDay': {'id': 'o9', 'name': 'Convocation', 'startDate': '2026-11-20', 'tentative': false}};
      await show(tester, SetupHolidaysScreen(progress: SetupProgress(course: scaled, sectionId: 's1', semesterId: 'm1'), standalone: true));
      expect(backend.sent('GET', '/off-days').single.query, {'courseId': 'c1'});

      // Straight through the API: the date picker is Flutter's own and is tested by Flutter.
      await SetupApi.addOffDay('c1', 'Convocation', '2026-11-20');
      expect(backend.sent('POST', '/off-days').single.body, {'courseId': 'c1', 'name': 'Convocation', 'startDate': '2026-11-20'});
    });
  });

  group('student details', () {
    final details = StudentDetails.fromJson({
      'student': {'id': 'st2', 'rollNumber': 'EB24210106005', 'fullName': 'NASIR AKHTAR', 'fatherName': 'AKHTAR ALI', 'email': null},
      'attendance': {
        'present': 2,
        'marked': 4,
        'percentage': 50,
        'min': 75,
        'shortage': true,
        'absentOn': [
          {'date': '2026-11-02', 'startTime': '09:00'},
          {'date': '2026-10-28', 'startTime': '11:00'},
        ],
      },
      'marks': {
        'total': 12.5,
        'outOf': 100,
        'assessments': [
          {'id': 'a1', 'name': 'Quiz 1', 'maxMarks': 10, 'isLab': false, 'marks': 7.5},
          {'id': 'a2', 'name': 'Lab Work', 'maxMarks': 20, 'isLab': true, 'marks': null},
        ],
      },
    });

    testWidgets('shows attendance, the missed classes and every mark', (tester) async {
      await show(tester, Scaffold(body: StudentDetailsView(data: details)));
      expect(find.text('NASIR AKHTAR'), findsOneWidget);
      expect(find.text('2 of 4 classes · line 75%'), findsOneWidget);
      expect(find.text('Short of attendance'), findsOneWidget);
      expect(find.text('MISSED 2 CLASSES'), findsOneWidget);
      expect(find.text('02 NOV · 09:00'), findsOneWidget);
      expect(find.text('7.5 / 10'), findsOneWidget);
      expect(find.text('Lab Work · Lab'), findsOneWidget);
      expect(find.text('12.5 / 100'), findsOneWidget);
    });

    testWidgets('loads one student of one section', (tester) async {
      final backend = FakeBackend()..overrides['GET /sections/s1/students/st2'] = {
        'student': {'id': 'st2', 'rollNumber': 'R', 'fullName': 'N', 'fatherName': null, 'email': null},
        'attendance': {'present': 0, 'marked': 0, 'percentage': null, 'min': 75, 'shortage': false, 'absentOn': []},
        'marks': {'total': 0, 'outOf': 100, 'assessments': []},
      };
      final loaded = await StudentsApi.details('s1', 'st2');
      expect(backend.sent('GET', '/sections/s1/students/st2'), hasLength(1));
      expect(loaded.percentage, isNull);
    });
  });

  test('topic import sends the files and reads back the topics', () async {
    final backend = FakeBackend()..overrides['POST /topics/extract'] = {'topics': ['Relational Model', 'Normalization']};
    final topics = await SetupApi.extractTopics([UploadFile(field: 'files', name: 'outline.jpg', bytes: Uint8List(4))]);
    expect(topics, ['Relational Model', 'Normalization']);
    expect(backend.sent('POST', '/topics/extract'), hasLength(1));
  });

  testWidgets('forgot password checks the email before asking Supabase', (tester) async {
    await show(tester, const ForgotPasswordScreen());
    await tester.enterText(find.byType(TextField), 'not-an-email');
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(find.text('Enter the email you signed up with.'), findsOneWidget);
  });
}
