import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/card_list.dart';
import '../../../shared/widgets/empty_note.dart';
import '../../../shared/widgets/hero_panel.dart';
import '../../../shared/widgets/prompts.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../courses/data/courses_api.dart';
import '../../papers/screens/paper_screen.dart';
import '../data/marks_api.dart';
import 'marks_entry_screen.dart';

/// What opening an assessment should do, because the same list serves two jobs.
enum AssessmentAction { marks, paper }

/// The course's assessments, and how much of its total they've used.
/// The teacher decides everything here: what exists and what it's worth.
class AssessmentsScreen extends StatefulWidget {
  const AssessmentsScreen({super.key, required this.course, required this.section, this.action = AssessmentAction.marks});

  final Course course;
  final Section section;
  final AssessmentAction action;

  @override
  State<AssessmentsScreen> createState() => _AssessmentsScreenState();
}

class _AssessmentsScreenState extends State<AssessmentsScreen> {
  late Future<AssessmentList> _data = MarksApi.assessments(widget.course.id);

  void _reload() => setState(() { _data = MarksApi.assessments(widget.course.id); });

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  void _openMarks(Assessment item) => _push(MarksEntryScreen(assessmentId: item.id, section: widget.section));
  void _openPaper(Assessment item) => _push(PaperScreen(course: widget.course, assessmentId: item.id));

  Future<void> _edit(AssessmentList list, [Assessment? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AssessmentDialog(courseId: widget.course.id, list: list, assessment: item),
    );
    if (saved == true) _reload();
  }

  Future<void> _remove(Assessment item) async {
    final agreed = await confirmAction(
      context,
      title: 'Delete ${item.name}?',
      message: 'Its marks and question paper are deleted too. This can\'t be undone.',
      action: 'Delete',
    );
    if (!agreed) return;
    try {
      await MarksApi.remove(item.id);
      _reload();
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  Future<void> _changeTotal(AssessmentList list) async {
    final text = await askText(context, title: 'Course total', label: 'Total marks', initial: markText(list.totalMarks), number: true);
    final total = num.tryParse(text ?? '');
    if (total == null) return;
    try {
      await MarksApi.setCourseTotal(widget.course.id, total);
      _reload();
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final forPaper = widget.action == AssessmentAction.paper;
    return Scaffold(
      appBar: AppBar(title: Text(forPaper ? 'Question papers' : 'Marks · Section ${widget.section.name}')),
      body: SafeArea(
        child: AsyncBody<AssessmentList>(
          future: _data,
          onRetry: _reload,
          builder: (context, list) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              HeroPanel(
                label: 'MARKS GIVEN OUT',
                tone: list.unallocated > 0 ? HeroTone.green : HeroTone.setup,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${markText(list.allocated)} / ${markText(list.totalMarks)}',
                        style: AppText.heroTitle.copyWith(color: AppColors.onGreen, fontSize: 34),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: AppColors.onGreen),
                      onPressed: () => _changeTotal(list),
                      child: const Text('Change total'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (list.assessments.isEmpty)
                EmptyNote(
                  title: 'No assessments yet',
                  message: 'Add quizzes, assignments, the final, anything. You decide what each is worth.',
                  action: 'Add assessment',
                  onAction: () => _edit(list),
                )
              else ...[
                Text('ASSESSMENTS', style: AppText.label),
                const SizedBox(height: 10),
                CardList(
                  children: [
                    for (final item in list.assessments)
                      _Row(
                        item: item,
                        students: list.students,
                        onTap: () => forPaper ? _openPaper(item) : _openMarks(item),
                        otherLabel: forPaper ? 'Enter marks' : 'Question paper',
                        onOther: () => forPaper ? _openMarks(item) : _openPaper(item),
                        onEdit: () => _edit(list, item),
                        onRemove: () => _remove(item),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: () => _edit(list), icon: const Icon(Icons.add_rounded), label: const Text('Add assessment')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.students,
    required this.onTap,
    required this.otherLabel,
    required this.onOther,
    required this.onEdit,
    required this.onRemove,
  });

  final Assessment item;
  final int students;
  final VoidCallback onTap;
  final String otherLabel;
  final VoidCallback onOther;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: AppText.rowTitle),
                  const SizedBox(height: 2),
                  Text(
                    '${markText(item.maxMarks)} marks · ${item.marksEntered} of $students entered',
                    style: AppText.small.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (item.isLab) const StatusPill('Lab', tone: PillTone.setup),
            PopupMenuButton<void>(
              tooltip: 'More',
              color: AppColors.line,
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
              itemBuilder: (_) => [
                PopupMenuItem(onTap: onOther, child: Text(otherLabel, style: AppText.body)),
                PopupMenuItem(onTap: onEdit, child: Text('Edit', style: AppText.body)),
                PopupMenuItem(onTap: onRemove, child: Text('Delete', style: AppText.body.copyWith(color: AppColors.dangerText))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Adds or edits an assessment. Pops true once saved.
class _AssessmentDialog extends StatefulWidget {
  const _AssessmentDialog({required this.courseId, required this.list, this.assessment});

  final String courseId;
  final AssessmentList list;
  final Assessment? assessment;

  @override
  State<_AssessmentDialog> createState() => _AssessmentDialogState();
}

class _AssessmentDialogState extends State<_AssessmentDialog> {
  late final _name = TextEditingController(text: widget.assessment?.name);
  // A new assessment starts with what's left: for the last one, that's already right.
  late final _marks = TextEditingController(
    text: markText(widget.assessment?.maxMarks ?? widget.list.unallocated),
  );
  late bool _isLab = widget.assessment?.isLab ?? false;
  bool _busy = false;
  String? _error;

  /// One tap instead of typing. "Quiz" becomes "Quiz 2" if "Quiz 1" exists.
  String _nextName(String base) {
    final used = widget.list.assessments.map((item) => item.name.toLowerCase()).toSet();
    if (base == 'Mid' || base == 'Final') return base;
    var number = 1;
    while (used.contains('$base $number'.toLowerCase())) {
      number++;
    }
    return '$base $number';
  }

  @override
  void dispose() {
    _name.dispose();
    _marks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final marks = num.tryParse(_marks.text.trim());
    if (name.isEmpty || marks == null || marks <= 0) {
      setState(() => _error = 'Enter a name and the marks.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final item = widget.assessment;
      if (item == null) {
        await MarksApi.add(widget.courseId, name: name, maxMarks: marks, isLab: _isLab);
      } else {
        await MarksApi.update(item.id, name: name, maxMarks: marks, isLab: _isLab);
      }
      if (mounted) Navigator.of(context).pop(true);
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
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(widget.assessment == null ? 'Add assessment' : 'Edit assessment', style: AppText.cardTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.assessment == null) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final base in const ['Quiz', 'Assignment', 'Mid', 'Final', 'Presentation', 'Lab'])
                    ActionChip(
                      label: Text(base),
                      onPressed: () => setState(() {
                        _name.text = _nextName(base);
                        if (base == 'Lab') _isLab = true;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(controller: _name, style: AppText.input, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(
              controller: _marks,
              style: AppText.mono,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Marks', helperText: '${markText(widget.list.unallocated)} of ${markText(widget.list.totalMarks)} left'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.green,
              value: _isLab,
              title: Text('Lab work', style: AppText.rowTitle),
              subtitle: Text('Counts in the Lab column of the result sheet', style: AppText.small.copyWith(color: AppColors.textMuted)),
              onChanged: (value) => setState(() => _isLab = value),
            ),
            if (_error != null) Text(_error!, style: AppText.small.copyWith(color: AppColors.dangerText)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
