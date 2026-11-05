import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../courses/data/courses_api.dart';

class QuestionPart {
  QuestionPart({required this.label, required this.text, required this.marks});

  QuestionPart.fromJson(Map<String, dynamic> json)
      : label = json['label'] as String,
        text = json['text'] as String,
        marks = json['marks'] as num;

  final String label; // "(a)"
  final String text;
  final num marks;

  Map<String, dynamic> toJson() => {'label': label, 'text': text, 'marks': marks};
}

class Question {
  Question.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        sectionId = json['sectionId'] as String,
        type = json['type'] as String,
        text = json['text'] as String,
        options = (json['options'] as List?)?.cast<String>(),
        parts = [for (final part in json['parts'] as List? ?? const []) QuestionPart.fromJson(part as Map<String, dynamic>)],
        difficulty = json['difficulty'] as String,
        marks = json['marks'] as num,
        status = json['status'] as String,
        source = json['source'] as String? ?? 'manual';

  final String id;
  final String sectionId;
  final String type; // free text; only "mcq" is special, because it needs options
  final String text;
  final List<String>? options;
  final List<QuestionPart> parts;
  final String difficulty; // easy, medium, hard
  final num marks;
  final String status; // draft, approved
  final String source; // ai, manual

  bool get isDraft => status == 'draft';
}

class PaperSection {
  PaperSection.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        title = json['title'] as String? ?? '',
        instructions = json['instructions'] as String? ?? '',
        attemptAny = json['attemptAny'] as int?,
        questions = [for (final item in json['questions'] as List? ?? const []) Question.fromJson(item as Map<String, dynamic>)];

  final String id;
  final String title; // empty on a plain list of questions
  final String instructions;
  final int? attemptAny; // students answer only this many
  final List<Question> questions;
}

class Paper {
  Paper.fromJson(Map<String, dynamic> json)
      : name = json['assessment']['name'] as String,
        maxMarks = json['assessment']['maxMarks'] as num,
        approvedMarks = json['approvedMarks'] as num,
        draftMarks = json['draftMarks'] as num,
        sections = [for (final item in json['sections'] as List) PaperSection.fromJson(item as Map<String, dynamic>)];

  final String name;
  final num maxMarks;
  final num approvedMarks;
  final num draftMarks;
  final List<PaperSection> sections;

  Iterable<Question> get questions => sections.expand((section) => section.questions);
  int get draftCount => questions.where((question) => question.isDraft).length;
  bool get isEmpty => questions.isEmpty;
}

/// What Gemini wrote compared with what was asked, so the teacher can decide if it's good enough.
class GenerateResult {
  GenerateResult.fromJson(Map<String, dynamic> json)
      : targetMarks = json['targetMarks'] as num,
        marksTotal = json['marksTotal'] as num,
        dropped = json['dropped'] as int? ?? 0;

  final num targetMarks;
  final num marksTotal;
  final int dropped; // broken questions thrown away
}

abstract final class PapersApi {
  /// The course outline, for choosing what the paper covers.
  static Future<List<TopicRef>> topics(String courseId) async {
    final reply = await api.get('/courses/$courseId/topics');
    return [for (final item in reply['topics'] as List) TopicRef.fromJson(item as Map<String, dynamic>)];
  }

  static Future<Paper> load(String assessmentId) async =>
      Paper.fromJson(await api.get('/assessments/$assessmentId/questions') as Map<String, dynamic>);

  /// Leaving [topicMarks] empty lets the backend use what has been taught so far.
  static Future<GenerateResult> generate(String assessmentId, {required String instructions, required Map<String, num?> topicMarks}) async {
    final reply = await api.post(
      '/assessments/$assessmentId/questions/generate',
      {
        if (instructions.isNotEmpty) 'instructions': instructions,
        if (topicMarks.isNotEmpty)
          'topics': [
            for (final entry in topicMarks.entries) {'id': entry.key, 'marks': ?entry.value},
          ],
      },
      ApiClient.aiTimeout,
    );
    return GenerateResult.fromJson(reply as Map<String, dynamic>);
  }

  static Future<void> regenerate(String questionId) => api.post('/questions/$questionId/regenerate', const <String, dynamic>{}, ApiClient.aiTimeout);

  static Future<void> addQuestion(String assessmentId, Map<String, dynamic> body) => api.post('/assessments/$assessmentId/questions', body);
  static Future<void> updateQuestion(String id, Map<String, dynamic> changes) => api.patch('/questions/$id', changes);
  static Future<void> removeQuestion(String id) => api.delete('/questions/$id');

  static Future<void> setApproved(String id, bool approved) => api.patch('/questions/$id', {'status': approved ? 'approved' : 'draft'});
  static Future<void> approveAll(String assessmentId) => api.patch('/assessments/$assessmentId/questions', {'status': 'approved'});

  /// [draftsOnly] keeps what the teacher already approved.
  static Future<void> clear(String assessmentId, {required bool draftsOnly}) =>
      api.delete('/assessments/$assessmentId/questions${draftsOnly ? '?status=draft' : ''}');

  static Future<void> addSection(String assessmentId, Map<String, dynamic> body) => api.post('/assessments/$assessmentId/sections', body);
  static Future<void> updateSection(String id, Map<String, dynamic> changes) => api.patch('/paper-sections/$id', changes);
  static Future<void> removeSection(String id) => api.delete('/paper-sections/$id');

  /// Sends the whole order at once, the way the backend stores it.
  static Future<void> reorder(String assessmentId, List<PaperSection> sections, Map<String, List<String>> order) => api.put(
        '/assessments/$assessmentId/questions',
        {
          'sections': [
            for (final section in sections) {'id': section.id, 'questionIds': order[section.id]},
          ],
        },
      );

  /// The printable paper. Only approved questions are on it.
  static Future<Uint8List> pdf(String assessmentId, String time) =>
      api.download('/assessments/$assessmentId/questions?format=pdf${time.isEmpty ? '' : '&time=${Uri.encodeQueryComponent(time)}'}');
}
