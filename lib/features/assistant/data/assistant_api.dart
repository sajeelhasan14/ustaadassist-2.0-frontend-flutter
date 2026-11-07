import '../../../core/api/api_client.dart';

/// One side of the conversation. The server stores nothing, so the app sends these back with each question.
class ChatTurn {
  const ChatTurn({required this.fromTeacher, required this.text});

  final bool fromTeacher;
  final String text;

  Map<String, String> toJson() => {'role': fromTeacher ? 'user' : 'assistant', 'text': text};
}

/// A change the assistant prepared. Nothing has happened yet: the app sends it only after the teacher taps Confirm.
class Proposal {
  Proposal.fromJson(Map<String, dynamic> json)
      : title = json['title'] as String,
        detail = json['detail'] as String,
        method = json['method'] as String,
        path = json['path'] as String,
        body = json['body'] as Map<String, dynamic>;

  final String title;
  final String detail;
  final String method; // POST or PATCH
  final String path;
  final Map<String, dynamic> body;
}

/// A small number shown under a reply, such as "2 BEHIND".
class ReplyStat {
  ReplyStat.fromJson(Map<String, dynamic> json)
      : value = json['value'] as String,
        label = json['label'] as String,
        tone = json['tone'] as String;

  final String value;
  final String label;
  final String tone; // normal, warning, good
}

class AssistantReply {
  AssistantReply.fromJson(Map<String, dynamic> json)
      : text = json['reply'] as String,
        proposals = [for (final item in json['proposals'] as List? ?? const []) Proposal.fromJson(item as Map<String, dynamic>)],
        stats = [for (final item in json['stats'] as List? ?? const []) ReplyStat.fromJson(item as Map<String, dynamic>)];

  final String text;
  final List<Proposal> proposals;
  final List<ReplyStat> stats;
}

abstract final class AssistantApi {
  /// The backend accepts this many earlier messages.
  static const _maxHistory = 40;

  /// [courseId] and [sectionId] say which course is open, so "who is short?" needs no explaining.
  static Future<AssistantReply> ask(String message, {required List<ChatTurn> history, String? courseId, String? sectionId}) async {
    final recent = history.length > _maxHistory ? history.sublist(history.length - _maxHistory) : history;
    final json = await api.post(
      '/assistant',
      {
        'message': message,
        'history': [for (final turn in recent) turn.toJson()],
        'courseId': ?courseId,
        'sectionId': ?sectionId,
      },
      ApiClient.aiTimeout,
    );
    return AssistantReply.fromJson(json as Map<String, dynamic>);
  }

  /// Sends a change the teacher has agreed to. It goes through the normal routes, so all their checks still apply.
  static Future<void> confirm(Proposal proposal) =>
      proposal.method == 'PATCH' ? api.patch(proposal.path, proposal.body) : api.post(proposal.path, proposal.body);
}
