import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/step_scaffold.dart';
import '../../courses/data/courses_api.dart';
import '../data/papers_api.dart';

/// Tells AI what paper to write. Everything is optional: with nothing chosen,
/// it uses what has been taught so far. Pops the [GenerateResult] once written.
class GeneratePaperScreen extends StatefulWidget {
  const GeneratePaperScreen({super.key, required this.course, required this.assessmentId, required this.paperName});

  final Course course;
  final String assessmentId;
  final String paperName;

  @override
  State<GeneratePaperScreen> createState() => _GeneratePaperScreenState();
}

class _GeneratePaperScreenState extends State<GeneratePaperScreen> {
  static const _ideas = {
    'MCQs only': 'MCQs only.',
    'Short': 'Short questions only.',
    'Long': 'Long questions only.',
    'Scenario': 'Scenario based questions.',
    'Mixed paper': 'Section A: MCQs. Section B: short questions. Section C: long questions with parts (a) and (b), attempt any 2.',
  };

  final _instructions = TextEditingController();
  late Future<List<TopicRef>> _topics = PapersApi.topics(widget.course.id);

  /// Ticked topics, each with its own marks box. Marks are numbers because
  /// wording like "mostly Testing" made the AI skip the other topics entirely.
  final Map<String, TextEditingController> _chosen = {};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _instructions.dispose();
    for (final controller in _chosen.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggle(TopicRef topic, bool ticked) {
    setState(() {
      if (ticked) {
        _chosen[topic.id] = TextEditingController();
      } else {
        _chosen.remove(topic.id)?.dispose();
      }
    });
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await PapersApi.generate(
        widget.assessmentId,
        instructions: _instructions.text.trim(),
        topicMarks: {for (final entry in _chosen.entries) entry.key: num.tryParse(entry.value.text.trim())},
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      title: widget.paperName,
      step: 'AI draft',
      headingTop: 'What should',
      headingBottom: 'it ask?',
      subtitle: 'Say it in your own words. Questions only, no answers, and you check everything before it counts.',
      error: _error,
      buttonLabel: _busy ? 'Writing…' : (_error == null ? 'Write the paper' : 'Try again'),
      onPressed: _busy ? null : _generate,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final idea in _ideas.entries)
              ActionChip(label: Text(idea.key), onPressed: _busy ? null : () => setState(() => _instructions.text = idea.value)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _instructions,
          enabled: !_busy,
          minLines: 3,
          maxLines: 6,
          style: AppText.input,
          decoration: const InputDecoration(hintText: '10 MCQs and 2 long questions with parts.'),
        ),
        const SizedBox(height: 20),
        Text('TOPICS', style: AppText.label),
        const SizedBox(height: 4),
        Text('Leave them all off to use what you have taught so far.', style: AppText.small.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 10),
        if (_busy)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppGlass.box(AppRadius.card),
            child: Row(
              children: [
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(width: 16),
                Expanded(child: Text('Writing your paper. A long paper can take two minutes.', style: AppText.body)),
              ],
            ),
          )
        else
          AsyncBody<List<TopicRef>>(
            future: _topics,
            onRetry: () => setState(() { _topics = PapersApi.topics(widget.course.id); }),
            builder: (context, topics) => Column(
              children: [
                for (final topic in topics)
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.green,
                          checkColor: AppColors.onGreen,
                          value: _chosen.containsKey(topic.id),
                          title: Text(topic.title, style: AppText.rowTitle),
                          onChanged: (ticked) => _toggle(topic, ticked ?? false),
                        ),
                      ),
                      if (_chosen[topic.id] case final marks?)
                        SizedBox(
                          width: 76,
                          child: TextField(
                            controller: marks,
                            style: AppText.mono,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: 'Marks', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
