import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ustaad_assist/core/api/api_client.dart';
import 'package:ustaad_assist/core/theme/app_theme.dart';
import 'package:ustaad_assist/features/courses/data/courses_api.dart';

/// One request a screen sent, so a test can check exactly what would reach the server.
class Call {
  Call(this.method, this.path, this.query, this.body);

  final String method;
  final String path;
  final Map<String, String> query;
  final dynamic body;

  @override
  String toString() => '$method $path';
}

/// Stands in for the real API. The replies copy the shapes in backend/docs/flows,
/// so a screen that misreads a field fails here instead of on a teacher's phone.
class FakeBackend {
  FakeBackend() {
    api = ApiClient(baseUrl: 'http://test/api/v1', token: () => 'token', client: MockClient(_handle));
  }

  final calls = <Call>[];

  /// Replies a test wants to change, by "METHOD /path". Wins over [replies].
  final overrides = <String, dynamic>{};

  /// Makes one route fail the way the backend does.
  void fail(String key, int status, String code, String message) {
    overrides[key] = http.Response(jsonEncode({'error': {'code': code, 'message': message}}), status);
  }

  Iterable<Call> sent(String method, String path) => calls.where((call) => call.method == method && call.path == path);

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path.replaceFirst('/api/v1', '');
    final key = '${request.method} $path';
    final isJson = request.headers['content-type']?.contains('json') ?? false;
    calls.add(Call(request.method, path, request.url.queryParameters, isJson ? jsonDecode(request.body) : null));
    final reply = overrides.containsKey(key) ? overrides[key] : replies[key];
    if (reply is http.Response) return reply;
    if (reply == null && !replies.containsKey(key) && !overrides.containsKey(key)) {
      return http.Response(jsonEncode({'error': {'code': 'not_found', 'message': 'No fake reply for $key'}}), 404);
    }
    return http.Response.bytes(utf8.encode(jsonEncode(reply)), 200, headers: {'content-type': 'application/json'});
  }
}

const today = '2026-11-05';

Map<String, dynamic> topic(String id, String title, String status, {int needed = 2, int taught = 0, int left = 2, List<String> dates = const []}) => {
      'id': id,
      'title': title,
      'position': 1,
      'classesNeeded': needed,
      'classesTaught': taught,
      'status': status,
      'classesLeft': left,
      'plannedDates': dates,
    };

Map<String, dynamic> session(String date, String status, {String? id, String start = '09:00', List<Map<String, String>> topics = const [], String? offDay, int present = 0, int absent = 0, bool extra = false}) => {
      'id': id,
      'date': date,
      'startTime': start,
      'endTime': '10:30',
      'status': status,
      'extra': extra,
      'note': null,
      'present': present,
      'absent': absent,
      'offDayName': offDay,
      'topics': topics,
    };

/// A section mid-semester: one class held, one missed, one today, some ahead.
Map<String, dynamic> calendar({int short = 0}) => {
      'today': today,
      'summary': {'held': 1, 'cancelled': 1, 'offDays': 1, 'notMarked': 1, 'remaining': 3},
      'plan': {
        'nextTopic': {'id': 't2', 'title': 'Normalization'},
        'topicsDone': 1,
        'topicsLeft': 3,
        'classesNeeded': 3 + short,
        'classesAvailable': 3,
        'classesShort': short,
        'topics': [
          topic('t1', 'Relational Model', 'done', needed: 1, taught: 1, left: 0),
          topic('t2', 'Normalization', 'in_progress', taught: 1, left: 1, dates: [today]),
          topic('t3', 'Transactions and Recovery in Large Systems', 'not_started', needed: 4, left: 4),
          topic('t4', 'Concurrency', 'not_started', dates: ['2026-11-09']),
        ],
      },
      'sessions': [
        session('2026-10-26', 'held', id: 'x1', present: 3, absent: 1, topics: [{'id': 't1', 'title': 'Relational Model'}]),
        session('2026-10-28', 'cancelled', id: 'x2'),
        session('2026-11-02', 'planned'),
        session('2026-11-04', 'off_day', offDay: 'Iqbal Day'),
        session(today, 'planned', topics: [{'id': 't2', 'title': 'Normalization'}]),
        session('2026-11-09', 'planned', topics: [{'id': 't4', 'title': 'Concurrency'}]),
        session('2026-11-11', 'planned', extra: true),
      ],
    };

final replies = <String, dynamic>{
  'GET /courses/c1/sections': {
    'sections': [
      {'id': 's1', 'name': 'A', 'studentCount': 3},
      {'id': 's2', 'name': 'B', 'studentCount': 0},
    ],
  },
  'GET /sections/s1/sessions': calendar(),
  'POST /sections/s1/sessions': {
    'session': {'id': 'x9', 'date': today, 'startTime': '09:00', 'endTime': '10:30', 'status': 'planned', 'extra': false, 'note': null},
  },
  'PATCH /sessions/x2': {'session': {'id': 'x2'}},
  'GET /sessions/x9/attendance': {
    'marked': false,
    'topics': [],
    'students': [
      {'id': 'st1', 'rollNumber': 'EB24210106003', 'fullName': 'ABDUL GHANI', 'present': true},
      {'id': 'st2', 'rollNumber': 'EB24210106005', 'fullName': 'NASIR AKHTAR', 'present': true},
      {'id': 'st3', 'rollNumber': 'EB24210106007', 'fullName': 'A VERY LONG STUDENT NAME THAT GOES ON AND ON AND ON', 'present': true},
    ],
  },
  'PUT /sessions/x9/attendance': {'present': 2, 'absent': 1},
  'GET /sections/s1/attendance': {
    'held': 4,
    'min': 75,
    'average': 83.3,
    'students': [
      {'id': 'st1', 'rollNumber': 'EB24210106003', 'fullName': 'ABDUL GHANI', 'present': 4, 'marked': 4, 'percentage': 100, 'shortage': false},
      {'id': 'st2', 'rollNumber': 'EB24210106005', 'fullName': 'NASIR AKHTAR', 'present': 2, 'marked': 4, 'percentage': 50, 'shortage': true},
      {'id': 'st3', 'rollNumber': 'EB24210106007', 'fullName': 'SANA', 'present': 0, 'marked': 0, 'percentage': null, 'shortage': false},
    ],
  },
  'GET /sections/s1/students': {
    'students': [
      {'id': 'st1', 'rollNumber': 'EB24210106003', 'fullName': 'ABDUL GHANI', 'fatherName': 'MUHAMMAD AFZAL', 'email': null},
      {'id': 'st2', 'rollNumber': 'EB24210106005', 'fullName': 'NASIR AKHTAR', 'fatherName': null, 'email': null},
    ],
  },
  'POST /sections/s1/import': {'added': 2, 'created': 2, 'reused': 0, 'skipped': []},
  'GET /courses/c1/assessments': {
    'totalMarks': 100,
    'allocated': 60,
    'unallocated': 40,
    'students': 3,
    'assessments': [
      {'id': 'a1', 'name': 'Quiz 1', 'maxMarks': 10, 'isLab': false, 'position': 1, 'marksEntered': 2},
      {'id': 'a2', 'name': 'Lab Work', 'maxMarks': 20, 'isLab': true, 'position': 2, 'marksEntered': 0},
      {'id': 'a3', 'name': 'Mid', 'maxMarks': 30, 'isLab': false, 'position': 3, 'marksEntered': 0},
    ],
  },
  'POST /courses/c1/assessments': {'assessment': {'id': 'a4'}},
  'GET /assessments/a1/marks': {
    'assessment': {'id': 'a1', 'name': 'Quiz 1', 'maxMarks': 10},
    'entered': 1,
    'students': [
      {'id': 'st1', 'rollNumber': 'EB24210106003', 'fullName': 'ABDUL GHANI', 'sectionName': 'A', 'marks': 7.5},
      {'id': 'st2', 'rollNumber': 'EB24210106005', 'fullName': 'NASIR AKHTAR', 'sectionName': 'A', 'marks': null},
      {'id': 'st3', 'rollNumber': 'EB24210106007', 'fullName': 'SANA', 'sectionName': 'A', 'marks': null},
    ],
  },
  'PUT /assessments/a1/marks': {'saved': 1, 'cleared': 0},
  'GET /assessments/a1/questions': {
    'assessment': {'id': 'a1', 'name': 'Quiz 1', 'maxMarks': 10},
    'approvedMarks': 2,
    'draftMarks': 8,
    'sections': [
      {
        'id': 'p1',
        'title': 'Section A',
        'instructions': 'Answer briefly.',
        'attemptAny': 2,
        'position': 1,
        'questions': [
          {'id': 'q1', 'sectionId': 'p1', 'topicId': 't2', 'type': 'mcq', 'text': 'Which normal form removes partial dependencies?', 'options': ['1NF', '2NF', '3NF', 'BCNF'], 'parts': null, 'difficulty': 'easy', 'marks': 2, 'status': 'approved', 'source': 'ai', 'position': 1},
          {'id': 'q2', 'sectionId': 'p1', 'topicId': null, 'type': 'long', 'text': 'Explain normalization.', 'options': null, 'parts': [{'label': '(a)', 'text': 'Define 1NF.', 'marks': 4}, {'label': '(b)', 'text': 'Define 2NF.', 'marks': 4}], 'difficulty': 'hard', 'marks': 8, 'status': 'draft', 'source': 'ai', 'position': 2},
        ],
      },
    ],
  },
  'PATCH /assessments/a1/questions': {'approved': 1},
  'PATCH /questions/q2': {'question': {}},
  'PUT /assessments/a1/questions': {'ok': true},
  'POST /assessments/a1/questions': {'question': {}},
  'GET /assessments/a2/questions': {
    'assessment': {'id': 'a2', 'name': 'Lab Work', 'maxMarks': 20},
    'approvedMarks': 0,
    'draftMarks': 0,
    'sections': [],
  },
  'POST /assessments/a2/questions/generate': {
    'sections': [],
    'targetMarks': 20,
    'marksTotal': 20,
    'topicPlan': [],
    'dropped': 0,
  },
  'GET /courses/c1/topics': {
    'topics': [
      {'id': 't1', 'title': 'Relational Model', 'position': 1, 'classesNeeded': 1},
      {'id': 't2', 'title': 'Normalization', 'position': 2, 'classesNeeded': 2},
    ],
  },
  'GET /sections/s1/results': {
    'course': {'id': 'c1', 'code': 'CS-301', 'title': 'Database Systems', 'creditHours': '2+1', 'totalMarks': 100},
    'section': 'A',
    'teacher': 'Sajeel Hasan',
    'header': {'department': 'Computer Science', 'year': '2nd'},
    'hasLab': true,
    'theoryMax': 80,
    'labMax': 20,
    'summary': {'students': 3, 'passed': 1, 'failed': 1, 'absent': 1, 'incomplete': 1},
    'students': [
      {'id': 'st1', 'rollNumber': 'EB24210106003', 'fullName': 'ABDUL GHANI', 'fatherName': null, 'theory': 60, 'lab': 15, 'total': 75, 'totalInWords': 'Seventy Five', 'percentage': 75, 'grade': 'B+', 'remarks': 'Passes', 'absent': false, 'missing': 0},
      {'id': 'st2', 'rollNumber': 'EB24210106005', 'fullName': 'NASIR AKHTAR', 'fatherName': null, 'theory': 20.5, 'lab': 5, 'total': 25.5, 'totalInWords': 'Twenty Five Point Five', 'percentage': 25.5, 'grade': 'F', 'remarks': 'Fail in Th. & Pr.', 'absent': false, 'missing': 1},
      {'id': 'st3', 'rollNumber': 'EB24210106007', 'fullName': 'SANA', 'fatherName': null, 'theory': null, 'lab': null, 'total': null, 'totalInWords': null, 'percentage': null, 'grade': null, 'remarks': 'Absent', 'absent': true, 'missing': 3},
    ],
  },
  'PATCH /courses/c1': {'course': {'id': 'c1', 'code': 'CS-301', 'title': 'Database Systems', 'semesterId': 'm1', 'totalMarks': 100}},
  'GET /courses/c1/materials': {
    'materials': [
      {'id': 'f1', 'courseId': 'c1', 'topicId': 't2', 'name': 'Normalization slides.pdf', 'mimeType': 'application/pdf', 'sizeBytes': 2516582, 'createdAt': '2026-11-01T10:00:00Z'},
      {'id': 'f2', 'courseId': 'c1', 'topicId': null, 'name': 'notes.txt', 'mimeType': 'text/plain', 'sizeBytes': 2048, 'createdAt': '2026-11-01T10:00:00Z'},
    ],
  },
  'GET /sections/s1/marks': {
    'totalMarks': 100,
    'allocated': 60,
    'assessments': [
      {'id': 'a1', 'name': 'Quiz 1', 'maxMarks': 10, 'average': 72.5},
      {'id': 'a2', 'name': 'Lab Work', 'maxMarks': 20, 'average': 41},
      {'id': 'a3', 'name': 'Mid', 'maxMarks': 30, 'average': null},
    ],
    'students': [],
  },
  'GET /sections/s1/timetable': {
    'slots': [
      {'weekday': 1, 'startTime': '09:00', 'endTime': '10:30'},
      {'weekday': 3, 'startTime': '11:00', 'endTime': '12:30'},
    ],
  },
  'PUT /sections/s1/timetable': {'slots': []},
};

final course = Course.fromJson(const {'id': 'c1', 'semesterId': 'm1', 'code': 'CS-301', 'title': 'Database Systems', 'totalMarks': 100});
final section = Section.fromJson(const {'id': 's1', 'name': 'A', 'studentCount': 3});

/// The two phones every screen must fit: a usual one and the smallest we support.
const phones = [(390.0, 844.0), (320.0, 568.0)];

/// Shows a screen at a phone size and waits until its data has arrived.
Future<void> show(WidgetTester tester, Widget screen, {double width = 390, double height = 844}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.current, home: screen));
  await tester.pumpAndSettle();
}
