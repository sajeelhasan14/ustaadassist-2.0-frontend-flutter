import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustaad_assist/features/courses/data/courses_api.dart';
import 'package:ustaad_assist/features/home/screens/my_courses_screen.dart';

Course course(String id, String title) => Course.fromJson({'id': id, 'code': 'X-$id', 'title': title, 'semesterId': 'm$id'});

Future<void> show(WidgetTester tester, MyCoursesData data) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: MyCoursesView(data: data, onOpen: (_) {}))));
  await tester.pump();
}

void main() {
  testWidgets('lists every course by name, even from different semesters', (tester) async {
    // Two semesters with different dates: the old Home showed only the newest one.
    await show(tester, MyCoursesData(teacherName: 'Sana Ahmed', courses: [course('1', 'Web Engineering'), course('2', 'Database Systems')]));
    expect(find.text('Web Engineering'), findsOneWidget);
    expect(find.text('Database Systems'), findsOneWidget);
    expect(find.text('New course'), findsOneWidget);
    expect(find.text('SA'), findsOneWidget);
    // Only the name: no course code on the card.
    expect(find.text('X-1'), findsNothing);
  });

  testWidgets('a new teacher sees one clear next step', (tester) async {
    await show(tester, MyCoursesData(teacherName: 'Sana Ahmed', courses: []));
    expect(find.text('No courses yet.'), findsOneWidget);
    expect(find.text('Create your first course'), findsOneWidget);
    expect(find.text('New course'), findsNothing);
  });
}
