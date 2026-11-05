import '../../../core/api/api_client.dart';
import '../../courses/data/courses_api.dart';

/// Points at one class before it has an id: its section, date and start time
/// are what the backend finds or creates it by.
class ClassRef {
  const ClassRef({required this.sectionId, required this.date, required this.startTime, required this.title});

  final String sectionId;
  final String date;
  final String startTime;
  final String title; // shown at the top, e.g. "Database Systems"
}

class RosterStudent {
  RosterStudent.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        rollNumber = json['rollNumber'] as String,
        fullName = json['fullName'] as String,
        present = json['present'] as bool;

  final String id;
  final String rollNumber;
  final String fullName;
  final bool present; // not marked yet: the backend suggests present
}

/// Everything the attendance screen needs for one class.
class AttendanceSheet {
  AttendanceSheet({required this.sessionId, required this.marked, required this.students, required this.topics, required this.outline});

  final String sessionId;
  final bool marked;
  final List<RosterStudent> students;
  final List<TopicRef> topics; // pre-filled: what was saved, otherwise what the plan says is next
  final List<PlanTopic> outline; // every topic, for changing the choice
}

class StudentAttendance {
  StudentAttendance.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        rollNumber = json['rollNumber'] as String,
        fullName = json['fullName'] as String,
        present = json['present'] as int,
        marked = json['marked'] as int,
        percentage = json['percentage'] as num?,
        shortage = json['shortage'] as bool;

  final String id;
  final String rollNumber;
  final String fullName;
  final int present;
  final int marked;
  final num? percentage; // null until a class has been marked
  final bool shortage;
}

class AttendanceReport {
  AttendanceReport.fromJson(Map<String, dynamic> json)
      : held = json['held'] as int,
        min = json['min'] as num,
        average = json['average'] as num?,
        students = [for (final item in json['students'] as List) StudentAttendance.fromJson(item as Map<String, dynamic>)];

  final int held;
  final num min; // below this a student is short of attendance
  final num? average;
  final List<StudentAttendance> students;

  /// The students below the line, lowest first, because those are the ones to act on.
  List<StudentAttendance> get short => students.where((item) => item.shortage).toList()
    ..sort((a, b) => (a.percentage ?? 0).compareTo(b.percentage ?? 0));
}

abstract final class AttendanceApi {
  /// A planned class has no id yet, so it's created first. Doing that twice is harmless.
  static Future<AttendanceSheet> open(ClassRef ref) async {
    final created = await api.post('/sections/${ref.sectionId}/sessions', {'date': ref.date, 'startTime': ref.startTime});
    final sessionId = created['session']['id'] as String;
    final (sheet, plan) = await (api.get('/sessions/$sessionId/attendance'), CoursesApi.plan(ref.sectionId)).wait;

    final saved = [for (final topic in sheet['topics'] as List? ?? const []) TopicRef.fromJson(topic as Map<String, dynamic>)];
    final thisClass = plan.sessions.where((item) => item.id == sessionId).firstOrNull;
    final suggested = thisClass?.topics.isNotEmpty == true ? thisClass!.topics : [?plan.nextTopic];
    return AttendanceSheet(
      sessionId: sessionId,
      marked: sheet['marked'] as bool,
      students: [for (final item in sheet['students'] as List) RosterStudent.fromJson(item as Map<String, dynamic>)],
      topics: saved.isNotEmpty ? saved : suggested,
      outline: plan.topics,
    );
  }

  /// Saves who was absent and what was taught together. Saving again replaces both.
  static Future<void> save(String sessionId, {required List<String> absent, required List<String> topicIds}) =>
      api.put('/sessions/$sessionId/attendance', {'absent': absent, 'topicIds': topicIds});

  static Future<void> cancel(String sectionId, ClassSession session) => api.post('/sections/$sectionId/sessions', {
        'date': session.date,
        'startTime': session.startTime,
        'status': 'cancelled',
      });

  static Future<void> restore(String sessionId) => api.patch('/sessions/$sessionId', {'status': 'planned'});

  /// A time that isn't in the timetable becomes an extra class.
  static Future<void> addExtra(String sectionId, {required String date, required String startTime, required String endTime}) =>
      api.post('/sections/$sectionId/sessions', {'date': date, 'startTime': startTime, 'endTime': endTime});

  static Future<AttendanceReport> report(String sectionId) async =>
      AttendanceReport.fromJson(await api.get('/sections/$sectionId/attendance') as Map<String, dynamic>);
}
