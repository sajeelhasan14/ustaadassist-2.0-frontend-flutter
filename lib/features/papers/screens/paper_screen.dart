import 'package:material_ui/material_ui.dart';

import '../../../core/save_file.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/hero_panel.dart';
import '../../../shared/widgets/prompts.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../courses/data/courses_api.dart';
import '../data/papers_api.dart';
import 'generate_paper_screen.dart';
import 'question_edit_screen.dart';

/// One assessment's question paper: read it, fix it, approve it, print it.
/// AI questions stay drafts until the teacher approves them, and only approved
/// questions reach the printed paper.
class PaperScreen extends StatefulWidget {
  const PaperScreen({super.key, required this.course, required this.assessmentId});

  final Course course;
  final String assessmentId;

  @override
  State<PaperScreen> createState() => _PaperScreenState();
}

class _PaperScreenState extends State<PaperScreen> {
  late Future<Paper> _data = PapersApi.load(widget.assessmentId);
  final Set<String> _rewriting = {}; // questions Gemini is rewriting right now

  void _reload() => setState(() { _data = PapersApi.load(widget.assessmentId); });

  /// Runs a change, then shows the fresh paper. A failure is shown, not swallowed.
  Future<void> _change(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) _reload();
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  Future<void> _generate(Paper paper) async {
    final result = await Navigator.of(context).push<GenerateResult>(
      MaterialPageRoute(builder: (_) => GeneratePaperScreen(course: widget.course, assessmentId: widget.assessmentId, paperName: paper.name)),
    );
    if (result == null || !mounted) return;
    _reload();
    // Gemini can miss the target. We say so instead of quietly changing its work.
    if (result.marksTotal != result.targetMarks) {
      showMessage(context, 'The draft has ${markText(result.marksTotal)} marks, and you need ${markText(result.targetMarks)}. Check it before approving.');
    } else if (result.dropped > 0) {
      showMessage(context, '${result.dropped} broken questions were left out.');
    }
  }

  Future<void> _editQuestion(Paper paper, {Question? question, String? sectionId}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => QuestionEditScreen(assessmentId: widget.assessmentId, question: question, sectionId: sectionId)),
    );
    if (saved == true) _reload();
  }

  Future<void> _rewrite(Question question) async {
    setState(() => _rewriting.add(question.id));
    await _change(() => PapersApi.regenerate(question.id));
    if (mounted) setState(() => _rewriting.remove(question.id));
  }

  Future<void> _removeQuestion(Question question) async {
    final agreed = await confirmAction(context, title: 'Delete this question?', message: question.text, action: 'Delete');
    if (agreed) await _change(() => PapersApi.removeQuestion(question.id));
  }

  /// Swaps a question with its neighbour. The backend stores the order of the whole paper.
  Future<void> _move(Paper paper, PaperSection section, int index, int by) async {
    final order = {for (final item in paper.sections) item.id: [for (final question in item.questions) question.id]};
    final ids = order[section.id]!;
    final moved = ids.removeAt(index);
    ids.insert(index + by, moved);
    await _change(() => PapersApi.reorder(widget.assessmentId, paper.sections, order));
  }

  Future<void> _editSection([PaperSection? section]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SectionDialog(assessmentId: widget.assessmentId, section: section),
    );
    if (saved == true) _reload();
  }

  Future<void> _removeSection(PaperSection section) async {
    final agreed = await confirmAction(
      context,
      title: 'Delete this section?',
      message: 'Its ${section.questions.length} questions are deleted too.',
      action: 'Delete',
    );
    if (agreed) await _change(() => PapersApi.removeSection(section.id));
  }

  Future<void> _clear({required bool draftsOnly}) async {
    final agreed = await confirmAction(
      context,
      title: draftsOnly ? 'Throw away the drafts?' : 'Clear the whole paper?',
      message: draftsOnly ? 'Questions you approved stay.' : 'Every question and section goes, including approved ones.',
      action: 'Clear',
    );
    if (agreed) await _change(() => PapersApi.clear(widget.assessmentId, draftsOnly: draftsOnly));
  }

  Future<void> _download(Paper paper) async {
    if (paper.approvedMarks == 0) {
      showMessage(context, 'Approve the questions first. Only approved questions are printed.');
      return;
    }
    final time = await askText(context, title: 'Time allowed', label: 'Printed on the paper', initial: '3 hours');
    if (time == null) return;
    try {
      final bytes = await PapersApi.pdf(widget.assessmentId, time);
      await saveFile(bytes, '${paper.name} ${widget.course.code}.pdf');
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Paper>(
      future: _data,
      builder: (context, snapshot) {
        final paper = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(paper?.name ?? 'Question paper'),
            actions: [
              if (paper != null)
                PopupMenuButton<void>(
                  tooltip: 'Paper options',
                  color: AppColors.line,
                  itemBuilder: (_) => [
                    PopupMenuItem(onTap: () => _download(paper), child: Text('Download PDF', style: AppText.body)),
                    PopupMenuItem(onTap: () => _generate(paper), child: Text('Generate more', style: AppText.body)),
                    PopupMenuItem(onTap: () => _editQuestion(paper), child: Text('Add my own question', style: AppText.body)),
                    PopupMenuItem(onTap: _editSection, child: Text('Add a section', style: AppText.body)),
                    if (paper.draftCount > 0) PopupMenuItem(onTap: () => _clear(draftsOnly: true), child: Text('Throw away drafts', style: AppText.body)),
                    if (!paper.isEmpty)
                      PopupMenuItem(onTap: () => _clear(draftsOnly: false), child: Text('Clear the paper', style: AppText.body.copyWith(color: AppColors.dangerText))),
                  ],
                ),
            ],
          ),
          body: SafeArea(
            child: AsyncBody<Paper>(
              future: _data,
              onRetry: _reload,
              builder: (context, paper) => paper.isEmpty ? _emptyPaper(paper) : _paper(paper),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyPaper(Paper paper) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        HeroPanel(
          label: 'NO PAPER YET · ${markText(paper.maxMarks)} MARKS',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Let AI write the first draft.', style: AppText.cardTitle.copyWith(color: AppColors.onGreen)),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.onGreen, foregroundColor: AppColors.text),
                onPressed: () => _generate(paper),
                child: const Text('Generate paper'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => _editQuestion(paper), child: const Text('Write my own questions')),
      ],
    );
  }

  Widget _paper(Paper paper) {
    var number = 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        HeroPanel(
          label: paper.draftCount > 0 ? '${paper.draftCount} ${paper.draftCount == 1 ? 'DRAFT' : 'DRAFTS'} TO CHECK' : 'ALL APPROVED',
          tone: paper.draftCount > 0 ? HeroTone.setup : HeroTone.green,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${markText(paper.approvedMarks)} / ${markText(paper.maxMarks)}',
                  style: AppText.heroTitle.copyWith(color: AppColors.onGreen, fontSize: 34),
                ),
              ),
              if (paper.draftCount > 0)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.onSetup, foregroundColor: AppColors.text),
                  onPressed: () => _change(() => PapersApi.approveAll(widget.assessmentId)),
                  child: const Text('Approve all'),
                )
              else
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.onGreen, foregroundColor: AppColors.text),
                  onPressed: () => _download(paper),
                  child: const Text('PDF'),
                ),
            ],
          ),
        ),
        for (final section in paper.sections) ...[
          const SizedBox(height: 20),
          _SectionHeader(section: section, onEdit: () => _editSection(section), onRemove: () => _removeSection(section)),
          for (final (index, question) in section.questions.indexed)
            _QuestionCard(
              number: ++number,
              question: question,
              rewriting: _rewriting.contains(question.id),
              onApprove: () => _change(() => PapersApi.setApproved(question.id, question.isDraft)),
              onEdit: () => _editQuestion(paper, question: question),
              onRewrite: () => _rewrite(question),
              onRemove: () => _removeQuestion(question),
              onUp: index == 0 ? null : () => _move(paper, section, index, -1),
              onDown: index == section.questions.length - 1 ? null : () => _move(paper, section, index, 1),
            ),
          TextButton.icon(
            onPressed: () => _editQuestion(paper, sectionId: section.id),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add a question here'),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section, required this.onEdit, required this.onRemove});

  final PaperSection section;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final detail = [
      if (section.attemptAny != null) 'Attempt any ${section.attemptAny}',
      if (section.instructions.isNotEmpty) section.instructions,
    ].join(' · ');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(section.title.isEmpty ? 'QUESTIONS' : section.title.toUpperCase(), style: AppText.label),
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(detail, style: AppText.small.copyWith(color: AppColors.textMuted)),
              ],
            ],
          ),
        ),
        PopupMenuButton<void>(
          tooltip: 'Section options',
          color: AppColors.line,
          icon: const Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.textMuted),
          itemBuilder: (_) => [
            PopupMenuItem(onTap: onEdit, child: Text('Edit section', style: AppText.body)),
            PopupMenuItem(onTap: onRemove, child: Text('Delete section', style: AppText.body.copyWith(color: AppColors.dangerText))),
          ],
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.rewriting,
    required this.onApprove,
    required this.onEdit,
    required this.onRewrite,
    required this.onRemove,
    required this.onUp,
    required this.onDown,
  });

  final int number;
  final Question question;
  final bool rewriting;
  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onRewrite;
  final VoidCallback onRemove;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final muted = AppText.small.copyWith(color: AppColors.textMuted);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.inner)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Q$number', style: AppText.mono.copyWith(color: AppColors.textMuted)),
              const SizedBox(width: 8),
              Expanded(child: Text('${markText(question.marks)} marks · ${question.type} · ${question.difficulty}', style: muted, overflow: TextOverflow.ellipsis)),
              PopupMenuButton<void>(
                tooltip: 'Question options',
                color: AppColors.line,
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
                itemBuilder: (_) => [
                  PopupMenuItem(onTap: onEdit, child: Text('Edit', style: AppText.body)),
                  PopupMenuItem(onTap: onRewrite, child: Text('Rewrite with AI', style: AppText.body)),
                  if (onUp != null) PopupMenuItem(onTap: onUp, child: Text('Move up', style: AppText.body)),
                  if (onDown != null) PopupMenuItem(onTap: onDown, child: Text('Move down', style: AppText.body)),
                  PopupMenuItem(onTap: onRemove, child: Text('Delete', style: AppText.body.copyWith(color: AppColors.dangerText))),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rewriting)
                  Text('Rewriting. This can take a minute.', style: muted)
                else
                  Text(question.text, style: AppText.body),
                for (final (index, option) in (question.options ?? const <String>[]).indexed)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('${String.fromCharCode(65 + index)}. $option', style: AppText.body)),
                for (final part in question.parts)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${part.label} ${part.text} [${markText(part.marks)}]', style: AppText.body),
                  ),
              ],
            ),
          ),
          // A Wrap, so the button drops to its own line if the two don't fit side by side.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(question.isDraft ? 'Draft' : 'Approved', tone: question.isDraft ? PillTone.setup : PillTone.success),
              TextButton(onPressed: rewriting ? null : onApprove, child: Text(question.isDraft ? 'Approve' : 'Back to draft')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Adds or edits a section of the paper. Pops true once saved.
class _SectionDialog extends StatefulWidget {
  const _SectionDialog({required this.assessmentId, this.section});

  final String assessmentId;
  final PaperSection? section;

  @override
  State<_SectionDialog> createState() => _SectionDialogState();
}

class _SectionDialogState extends State<_SectionDialog> {
  late final _title = TextEditingController(text: widget.section?.title);
  late final _instructions = TextEditingController(text: widget.section?.instructions);
  late final _attemptAny = TextEditingController(text: widget.section?.attemptAny?.toString());
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _attemptAny.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final attemptAny = int.tryParse(_attemptAny.text.trim());
    try {
      final section = widget.section;
      if (section == null) {
        await PapersApi.addSection(widget.assessmentId, {
          'title': _title.text.trim(),
          'instructions': _instructions.text.trim(),
          'attemptAny': ?attemptAny,
        });
      } else {
        await PapersApi.updateSection(section.id, {
          'title': _title.text.trim(),
          'instructions': _instructions.text.trim(),
          'attemptAny': attemptAny,
        });
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
      title: Text(widget.section == null ? 'Add a section' : 'Edit section', style: AppText.cardTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _title, style: AppText.input, decoration: const InputDecoration(labelText: 'Title, e.g. Section A')),
            const SizedBox(height: 10),
            TextField(controller: _instructions, style: AppText.input, maxLines: 2, decoration: const InputDecoration(labelText: 'Instructions (optional)')),
            const SizedBox(height: 10),
            TextField(
              controller: _attemptAny,
              style: AppText.mono,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Attempt any (blank = all)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppText.small.copyWith(color: AppColors.dangerText)),
            ],
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
