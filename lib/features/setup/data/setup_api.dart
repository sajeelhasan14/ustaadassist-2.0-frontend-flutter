import '../../../core/api/api_client.dart';
import '../../courses/data/courses_api.dart';

class Semester {
  Semester.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        startDate = json['startDate'] as String,
        endDate = json['endDate'] as String;

  final String id;
  final String startDate;
  final String endDate;
}

/// One weekly class. weekday: 1 = Monday … 7 = Sunday. Times are 24-hour text, "09:00".
class ClassSlot {
  ClassSlot({required this.weekday, required this.startTime, required this.endTime});

  final int weekday;
  String startTime;
  String endTime;

  Map<String, dynamic> toJson() => {'weekday': weekday, 'startTime': startTime, 'endTime': endTime};
}

class OffDay {
  OffDay.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        name = json['name'] as String,
        startDate = json['startDate'] as String,
        tentative = json['tentative'] as bool;

  final String id;
  final String name;
  final String startDate;
  final bool tentative;
}

/// What setup has made so far, handed from one step to the next.
class SetupProgress {
  SetupProgress({required this.course, required this.sectionId, required this.semesterId});

  final Course course;
  final String sectionId;
  final String semesterId;
}

abstract final class SetupApi {
  /// The latest semester, used to pre-fill the dates of a new course.
  static Future<Semester?> latestSemester() async {
    final list = (await api.get('/semesters'))['semesters'] as List;
    return list.isEmpty ? null : Semester.fromJson(list.first as Map<String, dynamic>);
  }

  /// The teacher never sees semesters. All courses in a term share their dates,
  /// so the same dates mean the same semester, and new dates make a new one.
  static Future<String> semesterFor(String startDate, String endDate) async {
    final list = (await api.get('/semesters'))['semesters'] as List;
    for (final item in list) {
      if (item['startDate'] == startDate && item['endDate'] == endDate) return item['id'] as String;
    }
    final created = await api.post('/semesters', {'name': '$startDate to $endDate', 'startDate': startDate, 'endDate': endDate});
    return created['semester']['id'] as String;
  }

  /// Creates the course. The backend also gives it section "A".
  static Future<SetupProgress> createCourse({required String semesterId, required String title, required String code}) async {
    final created = await api.post('/semesters/$semesterId/courses', {'title': title, 'code': code});
    return SetupProgress(
      course: Course.fromJson(created['course'] as Map<String, dynamic>),
      sectionId: created['section']['id'] as String,
      semesterId: semesterId,
    );
  }

  static Future<List<ClassSlot>> timetable(String sectionId) async {
    final reply = await api.get('/sections/$sectionId/timetable');
    return [
      for (final slot in reply['slots'] as List)
        ClassSlot(weekday: slot['weekday'] as int, startTime: slot['startTime'] as String, endTime: slot['endTime'] as String),
    ];
  }

  static Future<void> saveTimetable(String sectionId, List<ClassSlot> slots) =>
      api.put('/sections/$sectionId/timetable', {'slots': [for (final slot in slots) slot.toJson()]});

  /// How many classes are left, with holidays already taken out. Worked out by the backend.
  static Future<int> classesAvailable(String sectionId) async {
    final reply = await api.get('/sections/$sectionId/sessions');
    return reply['plan']['classesAvailable'] as int;
  }

  /// All saved together or not at all, with the classes shared out between them.
  static Future<void> addTopics(String courseId, List<String> titles, int classesAvailable) => api.post('/courses/$courseId/topics', {
        'titles': titles,
        if (classesAvailable > 0) 'spreadOver': classesAvailable,
      });

  static Future<List<OffDay>> offDays(String semesterId) async {
    final reply = await api.get('/off-days?semesterId=$semesterId');
    return [for (final item in reply['offDays'] as List) OffDay.fromJson(item as Map<String, dynamic>)];
  }

  static Future<OffDay> addOffDay(String name, String date) async {
    final reply = await api.post('/off-days', {'name': name, 'startDate': date});
    return OffDay.fromJson(reply['offDay'] as Map<String, dynamic>);
  }

  static Future<void> removeOffDay(String id) => api.delete('/off-days/$id');

  /// Moon sighting moved a holiday by [days]. Sending 0 confirms the date as it is.
  static Future<OffDay> shiftOffDay(String id, int days) async {
    final reply = await api.patch('/off-days/$id', days == 0 ? const <String, dynamic>{} : {'shiftDays': days});
    return OffDay.fromJson(reply['offDay'] as Map<String, dynamic>);
  }
}
