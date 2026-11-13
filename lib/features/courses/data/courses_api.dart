import '../../../core/api/api_client.dart';

class Course {
  Course.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        code = json['code'] as String,
        title = json['title'] as String,
        semesterId = json['semesterId'] as String? ?? '',
        totalMarks = json['totalMarks'] as num? ?? 100,
        minAttendance = json['minAttendance'] as num? ?? 75,
        gradeScale = [for (final band in json['gradeScale'] as List? ?? const []) GradeBand.fromJson(band as Map<String, dynamic>)],
        defaultGradeScale = json['defaultGradeScale'] as bool? ?? true;

  final String id;
  final String code;
  final String title;
  final String semesterId;
  final num totalMarks;
  final num minAttendance; // below this % a student is short; each course has its own
  final List<GradeBand> gradeScale; // highest first; below the last band = F
  final bool defaultGradeScale; // true = the course never changed the default scale
}

/// One grade and the lowest percentage that earns it, e.g. A+ from 90.
class GradeBand {
  GradeBand(this.grade, this.min);

  GradeBand.fromJson(Map<String, dynamic> json)
      : grade = json['grade'] as String,
        min = json['min'] as num;

  final String grade;
  final num min;

  Map<String, dynamic> toJson() => {'grade': grade, 'min': min};
}

class Section {
  Section.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        name = json['name'] as String,
        studentCount = json['studentCount'] as int;

  final String id;
  final String name;
  final int studentCount;
}

class PlanTopic {
  PlanTopic.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String? ?? '',
        title = json['title'] as String,
        status = json['status'] as String,
        classesNeeded = json['classesNeeded'] as int,
        classesTaught = json['classesTaught'] as int,
        classesLeft = json['classesLeft'] as int? ?? 0,
        plannedDates = [for (final date in json['plannedDates'] as List) date as String];

  final String id;
  final String title;
  final String status; // done, in_progress, not_started
  final int classesNeeded;
  final int classesTaught;
  final int classesLeft;
  final List<String> plannedDates;
}

/// Just enough of a topic to show it and send its id back.
class TopicRef {
  TopicRef.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        title = json['title'] as String;

  final String id;
  final String title;
}

/// One class in the calendar. `id` is null until something has happened to it,
/// because planned classes are worked out, not stored.
class ClassSession {
  ClassSession.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String?,
        date = json['date'] as String,
        startTime = json['startTime'] as String,
        endTime = json['endTime'] as String,
        status = json['status'] as String,
        extra = json['extra'] as bool? ?? false,
        note = json['note'] as String?,
        present = json['present'] as int? ?? 0,
        absent = json['absent'] as int? ?? 0,
        offDayName = json['offDayName'] as String?,
        topics = [for (final topic in json['topics'] as List? ?? const []) TopicRef.fromJson(topic as Map<String, dynamic>)];

  final String? id;
  final String date;
  final String startTime; // "09:00"
  final String endTime;
  final String status; // planned, held, cancelled, off_day
  final bool extra;
  final String? note;
  final int present;
  final int absent;
  final String? offDayName;
  final List<TopicRef> topics; // held: what was taught. Upcoming: what's planned.
}

/// The plan for one section. The backend works all of this out; the app only shows it.
class SectionPlan {
  SectionPlan.fromJson(Map<String, dynamic> json)
      : today = json['today'] as String? ?? '',
        classesHeld = json['summary']['held'] as int,
        notMarked = json['summary']['notMarked'] as int? ?? 0,
        classesNeeded = json['plan']['classesNeeded'] as int? ?? 0,
        nextTopic = json['plan']['nextTopic'] == null ? null : TopicRef.fromJson(json['plan']['nextTopic'] as Map<String, dynamic>),
        sessions = [for (final item in json['sessions'] as List? ?? const []) ClassSession.fromJson(item as Map<String, dynamic>)],
        classesAvailable = json['plan']['classesAvailable'] as int,
        classesShort = json['plan']['classesShort'] as int,
        topicsDone = json['plan']['topicsDone'] as int,
        topicsLeft = json['plan']['topicsLeft'] as int,
        topics = [for (final topic in json['plan']['topics'] as List) PlanTopic.fromJson(topic as Map<String, dynamic>)];

  final String today;
  final int classesHeld;
  final int notMarked; // past classes nobody took attendance for
  final int classesNeeded;
  final TopicRef? nextTopic;
  final List<ClassSession> sessions;
  final int classesAvailable;
  final int classesShort;
  final int topicsDone;
  final int topicsLeft;
  final List<PlanTopic> topics;
}

class CourseOverview {
  CourseOverview({required this.sections, required this.plan, required this.section});

  final List<Section> sections;
  final Section section;
  final SectionPlan plan;
}

abstract final class CoursesApi {
  /// [sectionId] picks a section; left out, the first one is shown.
  static Future<CourseOverview> overview(String courseId, {String? sectionId}) async {
    final reply = await api.get('/courses/$courseId/sections');
    final sections = [for (final item in reply['sections'] as List) Section.fromJson(item as Map<String, dynamic>)];
    final section = sections.firstWhere((item) => item.id == sectionId, orElse: () => sections.first);
    final plan = await api.get('/sections/${section.id}/sessions');
    return CourseOverview(sections: sections, section: section, plan: SectionPlan.fromJson(plan as Map<String, dynamic>));
  }

  /// The calendar and plan of one section.
  static Future<SectionPlan> plan(String sectionId) async =>
      SectionPlan.fromJson(await api.get('/sections/$sectionId/sessions') as Map<String, dynamic>);

  static Future<Course> update(String courseId, {String? title, String? code, num? minAttendance}) async {
    final reply = await api.patch('/courses/$courseId', {'title': ?title, 'code': ?code, 'minAttendance': ?minAttendance});
    return Course.fromJson(reply['course'] as Map<String, dynamic>);
  }

  /// Saves the course's own grade scale. `null` goes back to the default scale.
  static Future<Course> setGradeScale(String courseId, List<GradeBand>? bands) async {
    final reply = await api.patch('/courses/$courseId', {'gradeScale': bands?.map((band) => band.toJson()).toList()});
    return Course.fromJson(reply['course'] as Map<String, dynamic>);
  }

  static Future<void> remove(String courseId) => api.delete('/courses/$courseId');

  static Future<List<Section>> sections(String courseId) async {
    final reply = await api.get('/courses/$courseId/sections');
    return [for (final item in reply['sections'] as List) Section.fromJson(item as Map<String, dynamic>)];
  }

  static Future<void> addSection(String courseId, String name) => api.post('/courses/$courseId/sections', {'name': name});
  static Future<void> renameSection(String sectionId, String name) => api.patch('/sections/$sectionId', {'name': name});
  static Future<void> removeSection(String sectionId) => api.delete('/sections/$sectionId');
}
