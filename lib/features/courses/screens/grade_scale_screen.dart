import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/prompts.dart';
import '../data/courses_api.dart';

/// Edits one course's grade scale: each grade and the lowest % that earns it.
/// Opens filled with the current scale (the default one for a new course), so the
/// teacher only changes what differs. Pops the saved Course.
class GradeScaleScreen extends StatefulWidget {
  const GradeScaleScreen({super.key, required this.course});

  final Course course;

  @override
  State<GradeScaleScreen> createState() => _GradeScaleScreenState();
}

/// One editable line: a text box for the grade and one for its lowest %.
class _Line {
  _Line(String grade, num min)
      : grade = TextEditingController(text: grade),
        min = TextEditingController(text: markText(min));

  final TextEditingController grade;
  final TextEditingController min;

  void dispose() {
    grade.dispose();
    min.dispose();
  }
}

class _GradeScaleScreenState extends State<GradeScaleScreen> {
  late final List<_Line> _lines = [for (final band in widget.course.gradeScale) _Line(band.grade, band.min)];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  /// Checks the lines the way the server will, so the teacher sees the problem before saving.
  List<GradeBand>? _bands() {
    final bands = <GradeBand>[];
    for (final line in _lines) {
      final grade = line.grade.text.trim();
      final min = num.tryParse(line.min.text.trim());
      if (grade.isEmpty || min == null) {
        setState(() => _error = 'Every line needs a grade and a %.');
        return null;
      }
      if (min < 0 || min > 100) {
        setState(() => _error = '$grade: the % must be between 0 and 100.');
        return null;
      }
      bands.add(GradeBand(grade, min));
    }
    if (bands.isEmpty) {
      setState(() => _error = 'Keep at least one grade.');
      return null;
    }
    if (bands.map((band) => band.grade.toUpperCase()).toSet().length != bands.length) {
      setState(() => _error = 'Each grade can appear once.');
      return null;
    }
    if (bands.map((band) => band.min).toSet().length != bands.length) {
      setState(() => _error = "Two grades can't start at the same %.");
      return null;
    }
    return bands..sort((a, b) => b.min.compareTo(a.min));
  }

  Future<void> _save(List<GradeBand>? bands) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final course = await CoursesApi.setGradeScale(widget.course.id, bands);
      if (mounted) Navigator.of(context).pop(course);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  void _add() {
    // A new line goes below the lowest one, 5% under it, ready to rename.
    final lowest = _lines.map((line) => num.tryParse(line.min.text) ?? 0).fold<num>(100, (a, b) => b < a ? b : a);
    setState(() => _lines.add(_Line('', (lowest - 5).clamp(0, 100))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grade scale')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(widget.course.title, style: AppText.screenTitle),
            const SizedBox(height: 6),
            Text(
              'A student gets the first grade whose % they reach. Below the last one is F. Only this course uses this scale.',
              style: AppText.body.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: AppGlass.box(AppRadius.inner),
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('GRADE', style: AppText.label)),
                      SizedBox(width: 110, child: Text('FROM %', style: AppText.label)),
                      const SizedBox(width: 48),
                    ],
                  ),
                  for (final (index, line) in _lines.indexed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: line.grade,
                              style: AppText.input,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(hintText: 'e.g. B+', isDense: true, semanticCounterText: 'Grade ${index + 1}'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: line.min,
                              style: AppText.mono,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              decoration: const InputDecoration(suffixText: '%', isDense: true),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove this grade',
                            icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                            onPressed: _lines.length == 1
                                ? null
                                : () => setState(() {
                                      _lines.removeAt(index).dispose();
                                    }),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, right: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text('Below the last grade', style: AppText.small.copyWith(color: AppColors.textMuted))),
                        Text('F', style: AppText.rowTitle.copyWith(color: AppColors.dangerText)),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('Add a grade')),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: AppText.body.copyWith(color: AppColors.dangerText)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      final bands = _bands();
                      if (bands != null) _save(bands);
                    },
              child: Text(_busy ? 'Saving…' : 'Save grade scale'),
            ),
            if (!widget.course.defaultGradeScale) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: _busy ? null : () => _save(null), child: const Text('Use the default scale')),
            ],
          ],
        ),
      ),
    );
  }
}
