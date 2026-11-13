import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/prompts.dart';
import '../data/papers_api.dart';

class _PartFields {
  _PartFields({String text = '', String marks = ''})
      : text = TextEditingController(text: text),
        marks = TextEditingController(text: marks);

  final TextEditingController text;
  final TextEditingController marks;

  void dispose() {
    text.dispose();
    marks.dispose();
  }
}

/// Writes a new question or edits one. Any question can be plain, multiple
/// choice, or have parts, because the teacher decides the paper's shape.
/// Pops true once saved.
class QuestionEditScreen extends StatefulWidget {
  const QuestionEditScreen({super.key, required this.assessmentId, this.question, this.sectionId});

  final String assessmentId;
  final Question? question; // null = a new question
  final String? sectionId; // a new question's section; null = the last one

  @override
  State<QuestionEditScreen> createState() => _QuestionEditScreenState();
}

class _QuestionEditScreenState extends State<QuestionEditScreen> {
  late final _text = TextEditingController(text: widget.question?.text);
  late final _marks = TextEditingController(text: widget.question == null ? '' : markText(widget.question!.marks));
  late String _type = widget.question?.type ?? 'short';
  late String _difficulty = widget.question?.difficulty ?? 'medium';
  late final List<TextEditingController> _options = [
    for (final option in widget.question?.options ?? const <String>[]) TextEditingController(text: option),
  ];
  late final List<_PartFields> _parts = [
    for (final part in widget.question?.parts ?? const <QuestionPart>[]) _PartFields(text: part.text, marks: markText(part.marks)),
  ];
  bool _busy = false;
  String? _error;

  /// The usual types, plus this question's own if the AI or teacher used another.
  List<String> get _types => {'mcq', 'short', 'long', 'scenario', _type}.toList();

  @override
  void dispose() {
    _text.dispose();
    _marks.dispose();
    for (final option in _options) {
      option.dispose();
    }
    for (final part in _parts) {
      part.dispose();
    }
    super.dispose();
  }

  void _setType(String type) {
    setState(() {
      _type = type;
      // Multiple choice needs at least two choices, so they're ready to fill in.
      while (type == 'mcq' && _options.length < 2) {
        _options.add(TextEditingController());
      }
    });
  }

  String? _problem() {
    if (_text.text.trim().isEmpty) return 'Write the question.';
    if (_type == 'mcq' && _options.where((option) => option.text.trim().isNotEmpty).length < 2) return 'Add at least 2 options.';
    if (_parts.isNotEmpty) {
      final broken = _parts.any((part) => part.text.text.trim().isEmpty || (num.tryParse(part.marks.text.trim()) ?? 0) <= 0);
      return broken ? 'Every part needs its text and marks.' : null;
    }
    if ((num.tryParse(_marks.text.trim()) ?? 0) <= 0) return 'Enter the marks.';
    return null;
  }

  Future<void> _save() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final parts = [
      for (final (index, part) in _parts.indexed)
        QuestionPart(
          label: '(${String.fromCharCode(97 + index)})',
          text: part.text.text.trim(),
          marks: num.parse(part.marks.text.trim()),
        ).toJson(),
    ];
    final fields = {
      'type': _type,
      'text': _text.text.trim(),
      'difficulty': _difficulty,
      if (_type == 'mcq') 'options': [for (final option in _options) if (option.text.trim().isNotEmpty) option.text.trim()],
      if (parts.isEmpty) 'marks': num.parse(_marks.text.trim()),
    };
    try {
      final question = widget.question;
      if (question == null) {
        await PapersApi.addQuestion(widget.assessmentId, {...fields, 'sectionId': ?widget.sectionId, if (parts.isNotEmpty) 'parts': parts});
      } else {
        await PapersApi.updateQuestion(question.id, {...fields, 'parts': parts.isEmpty ? null : parts});
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.question == null ? 'New question' : 'Edit question')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final type in _types) ChoiceChip(label: Text(type), selected: type == _type, onSelected: (_) => _setType(type)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _text,
                    minLines: 3,
                    maxLines: 8,
                    style: AppText.input,
                    decoration: const InputDecoration(labelText: 'Question'),
                  ),
                  if (_type == 'mcq') ...[
                    const SizedBox(height: 16),
                    Text('OPTIONS', style: AppText.label),
                    const SizedBox(height: 8),
                    for (final (index, option) in _options.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: option,
                          style: AppText.input,
                          decoration: InputDecoration(
                            labelText: String.fromCharCode(65 + index),
                            suffixIcon: _options.length <= 2
                                ? null
                                : IconButton(
                                    tooltip: 'Remove this option',
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () => setState(() => _options.removeAt(index).dispose()),
                                  ),
                          ),
                        ),
                      ),
                    if (_options.length < 6)
                      TextButton.icon(
                        onPressed: () => setState(() => _options.add(TextEditingController())),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add an option'),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Text('PARTS', style: AppText.label),
                  const SizedBox(height: 8),
                  for (final (index, part) in _parts.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: part.text,
                              style: AppText.input,
                              maxLines: 3,
                              minLines: 1,
                              decoration: InputDecoration(labelText: '(${String.fromCharCode(97 + index)})'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 72,
                            child: TextField(
                              controller: part.marks,
                              style: AppText.mono,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Marks'),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove this part',
                            icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                            onPressed: () => setState(() => _parts.removeAt(index).dispose()),
                          ),
                        ],
                      ),
                    ),
                  if (_parts.length < 10)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _parts.add(_PartFields())),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add a part'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 92,
                        child: _parts.isEmpty
                            ? TextField(
                                controller: _marks,
                                style: AppText.mono,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Marks'),
                              )
                            : Text('Marks add up from the parts', style: AppText.small.copyWith(color: AppColors.textMuted)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          children: [
                            for (final level in const ['easy', 'medium', 'hard'])
                              ChoiceChip(label: Text(level), selected: level == _difficulty, onSelected: (_) => setState(() => _difficulty = level)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: AppText.small.copyWith(color: AppColors.dangerText)),
                    const SizedBox(height: 10),
                  ],
                  FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save question')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
