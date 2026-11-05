import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/step_scaffold.dart';
import '../data/setup_api.dart';
import 'setup_holidays_screen.dart';

/// Step 2: paste the outline, one topic per line. Design: Night screen 26.
/// With [standalone] it adds topics to an existing course, then simply closes.
class SetupTopicsScreen extends StatefulWidget {
  const SetupTopicsScreen({super.key, required this.progress, this.standalone = false});

  final SetupProgress progress;
  final bool standalone;

  @override
  State<SetupTopicsScreen> createState() => _SetupTopicsScreenState();
}

class _SetupTopicsScreenState extends State<SetupTopicsScreen> {
  final _outline = TextEditingController();
  int? _classes;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _outline.addListener(() => setState(() {}));
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await SetupApi.classesAvailable(widget.progress.sectionId);
      if (mounted) setState(() => _classes = classes);
    } catch (_) {
      // Only shown for information. It's fetched again when saving.
    }
  }

  @override
  void dispose() {
    _outline.dispose();
    super.dispose();
  }

  /// Pasted outlines often carry numbers or bullets: "1. Intro", "- Intro". We keep only the topic.
  List<String> get _topics => [
        for (final line in _outline.text.split('\n'))
          if (line.trim().replaceFirst(RegExp(r'^(\d+[.)]|[-•*])\s*'), '').trim() case final topic when topic.isNotEmpty) topic,
      ];

  Future<void> _next() async {
    final topics = _topics;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (topics.isNotEmpty) {
        final classes = _classes ?? await SetupApi.classesAvailable(widget.progress.sectionId);
        await SetupApi.addTopics(widget.progress.course.id, topics, classes);
      }
      if (!mounted) return;
      if (widget.standalone) {
        Navigator.of(context).pop(true);
      } else {
        await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SetupHolidaysScreen(progress: widget.progress)));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  String get _buttonLabel {
    if (_busy) return 'Saving…';
    if (widget.standalone) return 'Save topics';
    return _topics.isEmpty ? 'Skip for now' : 'Next: holidays';
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      title: widget.progress.course.title,
      step: widget.standalone ? 'Topics' : '2 / 3',
      headingTop: 'What are you',
      headingBottom: 'teaching?',
      subtitle: 'One topic per line. Paste it straight from your outline, and the classes are shared out for you.',
      error: _error,
      buttonLabel: _buttonLabel,
      onPressed: _busy || (widget.standalone && _topics.isEmpty) ? null : _next,
      children: [
        TextField(
          controller: _outline,
          minLines: 9,
          maxLines: 14,
          style: AppText.input.copyWith(height: 1.6),
          decoration: const InputDecoration(hintText: 'Introduction to Databases\nRelational Model\nNormalization'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Count(value: '${_topics.length}', label: 'topics', accent: true)),
            const SizedBox(width: 10),
            Expanded(child: _Count(value: _classes == null ? '–' : '$_classes', label: 'classes left')),
          ],
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, this.accent = false});

  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final foreground = accent ? AppColors.onGreen : AppColors.text;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: accent ? AppColors.green : AppColors.card, borderRadius: BorderRadius.circular(AppRadius.inner)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppText.cardTitle.copyWith(color: foreground, fontSize: 26)),
          const SizedBox(height: 2),
          Text(label, style: AppText.small.copyWith(color: accent ? AppColors.onGreenSoft : AppColors.textMuted)),
        ],
      ),
    );
  }
}
