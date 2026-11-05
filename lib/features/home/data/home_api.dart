import '../../../core/api/api_client.dart';
import '../../courses/data/courses_api.dart';

export '../../courses/data/courses_api.dart' show Course;

/// One class on the home screen. `id` is null until the class has been saved,
/// which happens when the teacher first opens it.
class TodayClass {
  TodayClass.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String?,
        sectionId = json['sectionId'] as String,
        sectionName = json['sectionName'] as String,
        courseId = json['courseId'] as String,
        courseCode = json['courseCode'] as String,
        courseTitle = json['courseTitle'] as String,
        startTime = json['startTime'] as String,
        endTime = json['endTime'] as String,
        status = json['status'] as String,
        present = json['present'] as int? ?? 0,
        absent = json['absent'] as int? ?? 0,
        topics = [for (final topic in json['topics'] as List? ?? const []) topic['title'] as String];

  final String? id;
  final String sectionId;
  final String sectionName;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String startTime; // "09:00:00" or "09:00"
  final String endTime;
  final String status; // planned, held, cancelled, off_day
  final int present;
  final int absent;
  final List<String> topics;

  String get shortStart => startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
}

class HomeData {
  HomeData({required this.teacherName, required this.date, required this.offDay, required this.classes, required this.courses});

  final String teacherName;
  final String date;
  final String? offDay;
  final List<TodayClass> classes;
  final List<Course> courses;

  /// The class to act on next: the first one still to happen today.
  TodayClass? get nextClass => classes.where((item) => item.status == 'planned').firstOrNull;
}

abstract final class HomeApi {
  /// Everything the home screen shows. The three requests don't depend on each
  /// other, so they run together instead of one after another.
  static Future<HomeData> load() async {
    final (me, today, semesters) = await (api.get('/me'), api.get('/today'), api.get('/semesters')).wait;
    final list = semesters['semesters'] as List;
    // Newest semester first, so the current courses are the first ones listed.
    final courses = list.isEmpty ? const [] : (await api.get('/semesters/${list.first['id']}/courses'))['courses'] as List;
    return HomeData(
      teacherName: me['teacher']['fullName'] as String,
      date: today['date'] as String,
      offDay: today['offDay']?['name'] as String?,
      classes: [for (final item in today['classes'] as List) TodayClass.fromJson(item as Map<String, dynamic>)],
      courses: [for (final item in courses) Course.fromJson(item as Map<String, dynamic>)],
    );
  }
}
