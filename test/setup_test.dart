import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustaad_assist/core/dates.dart';
import 'package:ustaad_assist/core/theme/app_theme.dart';
import 'package:ustaad_assist/features/courses/data/courses_api.dart';
import 'package:ustaad_assist/features/courses/screens/course_screen.dart';

Map<String, dynamic> planJson({List<Map<String, dynamic>> topics = const [], int available = 12, int short = 0}) => {
      'summary': {'held': 0},
      'plan': {
        'classesAvailable': available,
        'classesShort': short,
        'topicsDone': 0,
        'topicsLeft': topics.length,
        'topics': topics,
      },
    };

Map<String, dynamic> topicJson(String title, String status) => {
      'title': title,
      'status': status,
      'classesNeeded': 3,
      'classesTaught': 0,
      'plannedDates': ['2026-09-01'],
    };

Future<void> show(WidgetTester tester, SectionPlan plan, {double width = 390, List<Section>? sections}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final section = Section.fromJson(const {'id': 's1', 'name': 'A', 'studentCount': 0});
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.current,
      home: Scaffold(
        body: CourseView(
          course: Course.fromJson(const {'id': 'c1', 'code': 'CS-301', 'title': 'Database Systems'}),
          onOpen: (_) {},
          data: CourseOverview(sections: sections ?? [section], section: section, plan: plan),
          onSection: (_) {},
          onAddTopics: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('dates keep their text form and never shift', () {
    expect(isoDate(DateTime(2026, 9, 1)), '2026-09-01');
    expect(shortDate('2026-09-01'), '01 SEP');
    expect(longDate('2026-12-24'), '24 DEC 2026');
  });

  test('the plan reads the backend reply', () {
    final plan = SectionPlan.fromJson(jsonDecode(jsonEncode(planJson(topics: [topicJson('Normalization', 'done')], available: 5))) as Map<String, dynamic>);
    expect(plan.classesAvailable, 5);
    expect(plan.topics.single.title, 'Normalization');
    expect(plan.topics.single.plannedDates.single, '2026-09-01');
  });

  testWidgets('no topics asks for them', (tester) async {
    await show(tester, SectionPlan.fromJson(planJson()));
    expect(find.text('NO PLAN YET'), findsOneWidget);
    expect(find.text('Add topics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on track shows the classes left and the topics', (tester) async {
    await show(tester, SectionPlan.fromJson(planJson(topics: [topicJson('Normalization', 'in_progress')])));
    expect(find.text('12 classes left'), findsOneWidget);
    // The topic list sits below the bento tiles, so scroll down to it first.
    await tester.scrollUntilVisible(find.text('Normalization'), 200);
    expect(find.text('Normalization'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('3 classes · from 01 SEP'), findsOneWidget);
  });

  testWidgets('short of classes warns, and says class for one', (tester) async {
    await show(tester, SectionPlan.fromJson(planJson(topics: [topicJson('Joins', 'not_started')], short: 1)));
    expect(find.text('1 class short'), findsOneWidget);
    expect(find.text('BEHIND PLAN'), findsOneWidget);
  });

  testWidgets('one section hides the section picker, two show it', (tester) async {
    final plan = SectionPlan.fromJson(planJson());
    await show(tester, plan);
    expect(find.byType(ChoiceChip), findsNothing);
    await show(tester, plan, sections: [
      Section.fromJson(const {'id': 's1', 'name': 'A', 'studentCount': 0}),
      Section.fromJson(const {'id': 's2', 'name': 'B', 'studentCount': 0}),
    ]);
    expect(find.byType(ChoiceChip), findsNWidgets(2));
  });

  testWidgets('the course screen fits a small phone', (tester) async {
    await show(tester, SectionPlan.fromJson(planJson(topics: [topicJson('A very long topic name about transactions and recovery', 'in_progress')])), width: 320);
    expect(tester.takeException(), isNull);
  });
}
