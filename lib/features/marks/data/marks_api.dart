import '../../../core/api/api_client.dart';

class Assessment {
  Assessment.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        name = json['name'] as String,
        maxMarks = json['maxMarks'] as num,
        isLab = json['isLab'] as bool? ?? false,
        date = json['date'] as String?,
        marksEntered = json['marksEntered'] as int? ?? 0;

  final String id;
  final String name;
  final num maxMarks;
  final bool isLab; // counts in the Lab column of the result sheet
  final String? date; // optional, and usually empty: assessments are added whenever the teacher likes
  final int marksEntered;
}

class AssessmentList {
  AssessmentList.fromJson(Map<String, dynamic> json)
      : totalMarks = json['totalMarks'] as num,
        allocated = json['allocated'] as num,
        unallocated = json['unallocated'] as num,
        students = json['students'] as int,
        assessments = [for (final item in json['assessments'] as List) Assessment.fromJson(item as Map<String, dynamic>)];

  final num totalMarks;
  final num allocated;
  final num unallocated;
  final int students; // across all sections of the course
  final List<Assessment> assessments;
}

class MarkRow {
  MarkRow.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        rollNumber = json['rollNumber'] as String,
        fullName = json['fullName'] as String,
        marks = json['marks'] as num?;

  final String id;
  final String rollNumber;
  final String fullName;
  num? marks; // null = not entered, which is different from a real 0
}

class MarksSheet {
  MarksSheet.fromJson(Map<String, dynamic> json)
      : id = json['assessment']['id'] as String,
        name = json['assessment']['name'] as String,
        maxMarks = json['assessment']['maxMarks'] as num,
        students = [for (final item in json['students'] as List) MarkRow.fromJson(item as Map<String, dynamic>)];

  final String id;
  final String name;
  final num maxMarks;
  final List<MarkRow> students;
}

abstract final class MarksApi {
  static Future<AssessmentList> assessments(String courseId) async =>
      AssessmentList.fromJson(await api.get('/courses/$courseId/assessments') as Map<String, dynamic>);

  static Future<void> add(String courseId, {required String name, required num maxMarks, required bool isLab, String? date}) =>
      api.post('/courses/$courseId/assessments', {'name': name, 'maxMarks': maxMarks, 'isLab': isLab, 'date': ?date});

  /// A null [date] is sent on purpose: it clears any date already saved.
  static Future<void> update(String id, {required String name, required num maxMarks, required bool isLab, String? date}) =>
      api.patch('/assessments/$id', {'name': name, 'maxMarks': maxMarks, 'isLab': isLab, 'date': date});

  static Future<void> remove(String id) => api.delete('/assessments/$id');

  static Future<void> setCourseTotal(String courseId, num total) => api.patch('/courses/$courseId', {'totalMarks': total});

  static Future<MarksSheet> sheet(String assessmentId, String sectionId) async =>
      MarksSheet.fromJson(await api.get('/assessments/$assessmentId/marks?sectionId=$sectionId') as Map<String, dynamic>);

  /// Saves only the marks passed in; everyone else is left alone. null clears a mark.
  static Future<void> save(String assessmentId, Map<String, num?> marks) => api.put('/assessments/$assessmentId/marks', {
        'marks': [
          for (final entry in marks.entries) {'studentId': entry.key, 'marks': entry.value},
        ],
      });
}
