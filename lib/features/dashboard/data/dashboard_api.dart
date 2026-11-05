import '../../../core/api/api_client.dart';
import '../../attendance/data/attendance_api.dart';
import '../../courses/data/courses_api.dart';

class AssessmentAverage {
  AssessmentAverage.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        average = json['average'] as num?;

  final String name;
  final num? average; // % of the assessment's marks. null until someone has a mark.
}

class DashboardData {
  DashboardData({required this.plan, required this.attendance, required this.averages});

  final SectionPlan plan;
  final AttendanceReport attendance;
  final List<AssessmentAverage> averages;
}

abstract final class DashboardApi {
  /// The three answers don't depend on each other, so they're fetched together.
  /// Every number comes from the backend; this screen only arranges them.
  static Future<DashboardData> load(String sectionId) async {
    final (plan, attendance, marks) = await (
      CoursesApi.plan(sectionId),
      AttendanceApi.report(sectionId),
      api.get('/sections/$sectionId/marks'),
    ).wait;
    return DashboardData(
      plan: plan,
      attendance: attendance,
      averages: [for (final item in marks['assessments'] as List) AssessmentAverage.fromJson(item as Map<String, dynamic>)],
    );
  }
}
