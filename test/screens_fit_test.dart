import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustaad_assist/features/attendance/data/attendance_api.dart';
import 'package:ustaad_assist/features/attendance/screens/attendance_report_screen.dart';
import 'package:ustaad_assist/features/attendance/screens/classes_screen.dart';
import 'package:ustaad_assist/features/attendance/screens/take_attendance_screen.dart';
import 'package:ustaad_assist/features/courses/screens/course_screen.dart';
import 'package:ustaad_assist/features/courses/screens/course_settings_screen.dart';
import 'package:ustaad_assist/features/dashboard/screens/dashboard_screen.dart';
import 'package:ustaad_assist/features/marks/screens/assessments_screen.dart';
import 'package:ustaad_assist/features/marks/screens/marks_entry_screen.dart';
import 'package:ustaad_assist/features/materials/screens/materials_screen.dart';
import 'package:ustaad_assist/features/papers/screens/generate_paper_screen.dart';
import 'package:ustaad_assist/features/papers/screens/paper_screen.dart';
import 'package:ustaad_assist/features/papers/screens/question_edit_screen.dart';
import 'package:ustaad_assist/features/plan/screens/fix_plan_screen.dart';
import 'package:ustaad_assist/features/plan/screens/plan_screen.dart';
import 'package:ustaad_assist/features/results/screens/results_screen.dart';
import 'package:ustaad_assist/features/students/screens/capture_list_screen.dart';
import 'package:ustaad_assist/features/students/screens/students_screen.dart';

import 'support/fake_backend.dart';

/// Opens every screen on the fake backend at both phone sizes. A misread field
/// shows as the error view, and a layout that doesn't fit fails the test.
void main() {
  final screens = <String, Widget Function()>{
    'Course': () => CourseScreen(course: course),
    'Course settings': () => CourseSettingsScreen(course: course, section: section, onCourseChanged: (_) {}),
    'Classes': () => ClassesScreen(course: course, section: section),
    'Take attendance': () => const TakeAttendanceScreen(
          classRef: ClassRef(sectionId: 's1', date: today, startTime: '09:00', title: 'Database Systems'),
        ),
    'Attendance report': () => AttendanceReportScreen(course: course, section: section),
    'Students': () => StudentsScreen(section: section),
    'Capture list': () => CaptureListScreen(section: section),
    'Assessments': () => AssessmentsScreen(course: course, section: section),
    'Marks entry': () => MarksEntryScreen(assessmentId: 'a1', section: section),
    'Paper': () => PaperScreen(course: course, assessmentId: 'a1'),
    'Empty paper': () => PaperScreen(course: course, assessmentId: 'a2'),
    'Generate paper': () => GeneratePaperScreen(course: course, assessmentId: 'a2', paperName: 'Lab Work'),
    'New question': () => const QuestionEditScreen(assessmentId: 'a1'),
    'Results': () => ResultsScreen(course: course, section: section),
    'Materials': () => MaterialsScreen(course: course),
    'Plan': () => PlanScreen(course: course, section: section),
    'Dashboard': () => DashboardScreen(course: course, section: section),
  };

  for (final (width, height) in phones) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits at $width wide', (tester) async {
        FakeBackend();
        await show(tester, entry.value(), width: width, height: height);
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.cloud_off_rounded), findsNothing, reason: 'the screen could not read its data');
      });
    }

    testWidgets('Fix plan fits at $width wide', (tester) async {
      FakeBackend().overrides['GET /sections/s1/sessions'] = calendar(short: 3);
      await show(tester, FixPlanScreen(course: course, section: section), width: width, height: height);
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    });
  }
}
