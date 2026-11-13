import '../../../core/api/api_client.dart';

class Student {
  Student.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        rollNumber = json['rollNumber'] as String,
        fullName = json['fullName'] as String,
        fatherName = json['fatherName'] as String?;

  final String id;
  final String rollNumber; // the seat number
  final String fullName;
  final String? fatherName;
}

/// One row read from a class list. The text can change, because the teacher fixes rows here.
class ExtractedRow {
  ExtractedRow.fromJson(Map<String, dynamic> json)
      : row = json['row'] as int,
        rollNumber = json['rollNumber'] as String? ?? '',
        fullName = json['fullName'] as String? ?? '',
        fatherName = json['fatherName'] as String?,
        status = json['status'] as String,
        message = json['message'] as String?;

  final int row;
  String rollNumber;
  String fullName;
  String? fatherName;
  final String status;
  final String? message;

  /// False once the teacher has said a flagged row is fine or has changed it.
  bool flagged = true;

  /// Already in this course, so saving would change nothing.
  bool get isSkipped => status == 'already_enrolled' || status == 'in_other_section';
  bool get isReady => status == 'new' || status == 'existing';

  Map<String, dynamic> toJson() => {'rollNumber': rollNumber, 'fullName': fullName, 'fatherName': ?fatherName};
}

class ExtractedList {
  ExtractedList.fromJson(Map<String, dynamic> json)
      : rows = [for (final item in json['students'] as List) ExtractedRow.fromJson(item as Map<String, dynamic>)],
        warnings = [for (final item in json['warnings'] as List? ?? const []) item as String];

  final List<ExtractedRow> rows;
  final List<String> warnings;
}

class ImportResult {
  ImportResult.fromJson(Map<String, dynamic> json)
      : added = json['added'] as int,
        skipped = (json['skipped'] as List? ?? const []).length;

  final int added;
  final int skipped;
}

abstract final class StudentsApi {
  static Future<List<Student>> list(String sectionId) async {
    final reply = await api.get('/sections/$sectionId/students');
    return [for (final item in reply['students'] as List) Student.fromJson(item as Map<String, dynamic>)];
  }

  static Future<void> add(String sectionId, {required String rollNumber, required String fullName, String? fatherName}) =>
      api.post('/sections/$sectionId/students', {'rollNumber': rollNumber, 'fullName': fullName, 'fatherName': ?fatherName});

  /// Changing a student shows in every course they're in, because there's only one record of them.
  static Future<void> update(String id, {required String rollNumber, required String fullName, String? fatherName}) =>
      api.patch('/students/$id', {'rollNumber': rollNumber, 'fullName': fullName, 'fatherName': fatherName});

  /// Takes them out of this section only. The student and their other courses stay.
  /// One student in one section: details, attendance with the missed dates, and marks.
  static Future<StudentDetails> details(String sectionId, String studentId) async =>
      StudentDetails.fromJson(await api.get('/sections/$sectionId/students/$studentId') as Map<String, dynamic>);

  static Future<void> remove(String sectionId, String studentId) => api.delete('/sections/$sectionId/students/$studentId');

  /// Reads the list with AI. Saves nothing: the teacher checks the rows first.
  static Future<ExtractedList> extract(String sectionId, List<UploadFile> files) async {
    final reply = await api.upload('/students/extract', files, fields: {'sectionId': sectionId}, timeout: ApiClient.aiTimeout);
    return ExtractedList.fromJson(reply as Map<String, dynamic>);
  }

  /// Saves every row in one go, or none of them.
  static Future<ImportResult> import(String sectionId, List<ExtractedRow> rows) async {
    final reply = await api.post('/sections/$sectionId/import', {'students': [for (final row in rows) row.toJson()]});
    return ImportResult.fromJson(reply as Map<String, dynamic>);
  }
}

/// Everything the student details screen shows. The backend does every sum.
class StudentDetails {
  StudentDetails.fromJson(Map<String, dynamic> json)
      : student = Student.fromJson(json['student'] as Map<String, dynamic>),
        email = json['student']['email'] as String?,
        present = json['attendance']['present'] as int,
        marked = json['attendance']['marked'] as int,
        percentage = json['attendance']['percentage'] as num?,
        line = json['attendance']['min'] as num,
        shortage = json['attendance']['shortage'] as bool,
        absentOn = [for (final day in json['attendance']['absentOn'] as List) (date: day['date'] as String, startTime: day['startTime'] as String)],
        total = json['marks']['total'] as num,
        outOf = json['marks']['outOf'] as num,
        marks = [
          for (final item in json['marks']['assessments'] as List)
            (name: item['name'] as String, maxMarks: item['maxMarks'] as num, isLab: item['isLab'] as bool, marks: item['marks'] as num?),
        ];

  final Student student;
  final String? email;
  final int present;
  final int marked; // classes this student was marked in
  final num? percentage; // null until a class has been marked
  final num line; // the course's attendance line
  final bool shortage;
  final List<({String date, String startTime})> absentOn; // newest first
  final num total;
  final num outOf;
  final List<({String name, num maxMarks, bool isLab, num? marks})> marks; // null = not entered
}

