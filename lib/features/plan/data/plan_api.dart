import '../../../core/api/api_client.dart';
import '../../courses/data/courses_api.dart';

/// A change that closes the gap, worked out from the plan so the teacher only picks one.
class TopicCut {
  TopicCut({required this.topic, required this.newClasses});

  final PlanTopic topic;
  final int newClasses;
}

abstract final class PlanApi {
  static Future<void> updateTopic(String id, {String? title, int? classesNeeded}) =>
      api.patch('/topics/$id', {'title': ?title, 'classesNeeded': ?classesNeeded});

  static Future<void> removeTopic(String id) => api.delete('/topics/$id');

  static Future<void> reorderTopics(String courseId, List<String> topicIds) => api.put('/courses/$courseId/topics', {'topicIds': topicIds});

  /// Takes classes off the last unfinished topics, keeping at least one class each,
  /// until the gap is closed or nothing more can be taken.
  static List<TopicCut> shortenSuggestion(SectionPlan plan) {
    var left = plan.classesShort;
    final cuts = <TopicCut>[];
    for (final topic in plan.topics.reversed) {
      if (left == 0) break;
      final spare = topic.classesLeft - 1;
      if (spare <= 0) continue;
      final taken = spare < left ? spare : left;
      cuts.add(TopicCut(topic: topic, newClasses: topic.classesNeeded - taken));
      left -= taken;
    }
    return cuts;
  }

  /// The last topics nobody has started, just enough of them to close the gap.
  static List<PlanTopic> dropSuggestion(SectionPlan plan) {
    var left = plan.classesShort;
    final dropped = <PlanTopic>[];
    for (final topic in plan.topics.reversed) {
      if (left <= 0) break;
      if (topic.status != 'not_started') continue;
      dropped.add(topic);
      left -= topic.classesLeft;
    }
    return dropped;
  }
}
