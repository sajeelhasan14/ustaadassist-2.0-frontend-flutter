import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustaad_assist/features/home/data/home_api.dart';
import 'package:ustaad_assist/features/home/screens/home_screen.dart';

Map<String, dynamic> classJson(String start, String status, {List<String> topics = const []}) => {
      'id': null,
      'sectionId': 's1',
      'sectionName': 'A',
      'courseId': 'c1',
      'courseCode': 'CS-301',
      'courseTitle': 'Database Systems',
      'startTime': start,
      'endTime': '10:30:00',
      'status': status,
      'present': 0,
      'absent': 0,
      'topics': [for (final title in topics) {'id': 't', 'title': title}],
    };

HomeData data({List<Map<String, dynamic>> classes = const [], String? offDay, List<Course> courses = const []}) => HomeData(
      teacherName: 'Sajeel Hasan',
      date: '2026-11-05',
      offDay: offDay,
      classes: [for (final item in classes) TodayClass.fromJson(item)],
      courses: courses,
    );

Future<void> show(WidgetTester tester, HomeData value) async {
  // Fonts come from the network at runtime, which tests don't have.
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomeView(data: value, onOpen: (_) {}))));
  await tester.pump();
}

void main() {
  test('the next class is the first planned one, not a finished one', () {
    final value = data(classes: [classJson('09:00:00', 'held'), classJson('11:00:00', 'planned', topics: ['Normalization'])]);
    expect(value.nextClass?.shortStart, '11:00');
  });

  test('nothing planned means no next class', () {
    expect(data(classes: [classJson('09:00:00', 'held')]).nextClass, isNull);
  });

  testWidgets('shows the next class topic and the initials', (tester) async {
    await show(tester, data(classes: [classJson('11:00:00', 'planned', topics: ['Normalization'])]));
    // Twice on purpose: in the green panel and in the Today list.
    expect(find.text('Normalization'), findsNWidgets(2));
    expect(find.text('NEXT CLASS · 11:00'), findsOneWidget);
    expect(find.text('SH'), findsOneWidget);
  });

  testWidgets('an off day replaces the next class', (tester) async {
    await show(tester, data(offDay: 'Iqbal Day'));
    expect(find.text('Iqbal Day'), findsOneWidget);
    expect(find.textContaining('NEXT CLASS'), findsNothing);
  });

  testWidgets('says so when there is nothing today', (tester) async {
    await show(tester, data());
    expect(find.text('No classes today.'), findsOneWidget);
    expect(find.text('No courses yet.'), findsOneWidget);
  });

  testWidgets('says all done once every class is finished', (tester) async {
    await show(tester, data(classes: [classJson('09:00:00', 'held')]));
    expect(find.text('All done for today.'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
