import 'dart:typed_data';

import '../../../core/api/api_client.dart';

class ResultRow {
  ResultRow.fromJson(Map<String, dynamic> json)
      : rollNumber = json['rollNumber'] as String,
        fullName = json['fullName'] as String,
        theory = json['theory'] as num?,
        lab = json['lab'] as num?,
        total = json['total'] as num?,
        grade = json['grade'] as String?,
        remarks = json['remarks'] as String,
        absent = json['absent'] as bool,
        missing = json['missing'] as int;

  final String rollNumber;
  final String fullName;
  final num? theory;
  final num? lab;
  final num? total;
  final String? grade;
  final String remarks; // "Passes", "Fail", "Fail in Theory", "Absent"…
  final bool absent;
  final int missing; // assessments with no mark yet

  bool get failed => remarks.startsWith('Fail');
}

/// The lines printed at the top of the result sheet.
class SheetHeader {
  SheetHeader(this.values);

  SheetHeader.fromJson(Map<String, dynamic> json) : values = {for (final entry in json.entries) entry.key: '${entry.value}'};

  final Map<String, String> values;
}

class ResultSheet {
  ResultSheet.fromJson(Map<String, dynamic> json)
      : code = json['course']['code'] as String,
        creditHours = json['course']['creditHours'] as String? ?? '',
        totalMarks = json['course']['totalMarks'] as num,
        section = json['section'] as String,
        hasLab = json['hasLab'] as bool,
        theoryMax = json['theoryMax'] as num,
        labMax = json['labMax'] as num,
        header = SheetHeader.fromJson(json['header'] as Map<String, dynamic>? ?? const {}),
        studentCount = json['summary']['students'] as int,
        passed = json['summary']['passed'] as int,
        failed = json['summary']['failed'] as int,
        absent = json['summary']['absent'] as int,
        incomplete = json['summary']['incomplete'] as int,
        students = [for (final item in json['students'] as List) ResultRow.fromJson(item as Map<String, dynamic>)];

  final String code;
  final String creditHours;
  final num totalMarks;
  final String section;
  final bool hasLab;
  final num theoryMax;
  final num labMax;
  final SheetHeader header;
  final int studentCount;
  final int passed;
  final int failed;
  final int absent;
  final int incomplete; // some marks but not all: the sheet isn't final yet
  final List<ResultRow> students;
}

/// The three files a section can produce. [path] is the route, [name] the start of the file name.
enum SheetKind {
  result('results', 'Result sheet'),
  marks('marks', 'Marksheet'),
  attendance('attendance', 'Attendance sheet');

  const SheetKind(this.path, this.name);

  final String path;
  final String name;
}

abstract final class ResultsApi {
  static Future<ResultSheet> load(String sectionId) async =>
      ResultSheet.fromJson(await api.get('/sections/$sectionId/results') as Map<String, dynamic>);

  /// [format] is `pdf` or `xlsx`.
  static Future<Uint8List> file(String sectionId, SheetKind kind, String format) =>
      api.download('/sections/$sectionId/${kind.path}?format=$format');

  static Future<void> saveDetails(String courseId, {required String creditHours, required Map<String, String> header}) =>
      api.patch('/courses/$courseId', {'creditHours': creditHours, 'resultHeader': header});
}
