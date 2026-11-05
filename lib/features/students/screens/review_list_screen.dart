import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/card_list.dart';
import '../../../shared/widgets/hero_panel.dart';
import '../../../shared/widgets/prompts.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../courses/data/courses_api.dart';
import '../data/students_api.dart';

/// Checks what was read before anything is saved. A wrong seat number would
/// follow that student all semester, so flagged rows must be sorted out first.
/// Design: Night screen 35.
class ReviewListScreen extends StatefulWidget {
  const ReviewListScreen({super.key, required this.section, required this.list});

  final Section section;
  final ExtractedList list;

  @override
  State<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends State<ReviewListScreen> {
  late final List<ExtractedRow> _rows = [...widget.list.rows];
  bool _busy = false;
  String? _error;

  /// Rows the backend flagged and the teacher hasn't sorted out yet.
  bool _needsLook(ExtractedRow row) => !row.isReady && !row.isSkipped && row.flagged;

  /// The teacher changed the row, or said it's right. A blank is never right.
  bool _isBlank(ExtractedRow row) => row.rollNumber.trim().isEmpty || row.fullName.trim().isEmpty;

  List<ExtractedRow> get _toSave => _rows.where((row) => !row.isSkipped).toList();
  int get _problems => _rows.where((row) => _needsLook(row) || (!row.isSkipped && _isBlank(row))).length;

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await StudentsApi.import(widget.section.id, _toSave);
      if (!mounted) return;
      showMessage(context, '${result.added} added.');
      Navigator.of(context).pop(true);
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
    final problems = _problems;
    final count = _toSave.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Check the list')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  HeroPanel(
                    tone: problems > 0 ? HeroTone.danger : HeroTone.green,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          problems > 0 ? '$problems ${problems == 1 ? 'row needs' : 'rows need'} you' : 'All clear',
                          style: AppText.heroTitle.copyWith(color: AppColors.onGreen, fontSize: 30),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nothing is saved until you confirm. A wrong seat number follows that student all semester.',
                          style: AppText.small.copyWith(color: AppColors.onGreen),
                        ),
                      ],
                    ),
                  ),
                  for (final warning in widget.list.warnings) ...[
                    const SizedBox(height: 10),
                    Text(warning, style: AppText.small.copyWith(color: AppColors.warningText)),
                  ],
                  const SizedBox(height: 18),
                  if (_rows.isEmpty)
                    Text('No students were found. Try a clearer photo or another file.', style: AppText.body.copyWith(color: AppColors.textMuted))
                  else
                    CardList(
                      children: [
                        for (final row in _rows)
                          _ReviewRow(
                            key: ObjectKey(row),
                            row: row,
                            needsLook: _needsLook(row) || (!row.isSkipped && _isBlank(row)),
                            onChanged: () => setState(() {}),
                            onRemove: () => setState(() => _rows.remove(row)),
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
                  FilledButton(
                    onPressed: _busy || problems > 0 || count == 0 ? null : _confirm,
                    child: Text(_busy ? 'Saving…' : 'Confirm $count ${count == 1 ? 'student' : 'students'}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatefulWidget {
  const _ReviewRow({super.key, required this.row, required this.needsLook, required this.onChanged, required this.onRemove});

  final ExtractedRow row;
  final bool needsLook;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_ReviewRow> createState() => _ReviewRowState();
}

class _ReviewRowState extends State<_ReviewRow> {
  late final _roll = TextEditingController(text: widget.row.rollNumber);
  late final _name = TextEditingController(text: widget.row.fullName);

  @override
  void dispose() {
    _roll.dispose();
    _name.dispose();
    super.dispose();
  }

  void _edited() {
    widget.row
      ..rollNumber = _roll.text
      ..fullName = _name.text
      ..flagged = false;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    if (row.isSkipped) return _plain(row, trailing: const StatusPill('Skipped'));
    if (row.isReady && !widget.needsLook) return _plain(row);
    return Container(
      color: widget.needsLook ? AppColors.dangerTint : null,
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roll,
                  style: AppText.mono,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Seat number', isDense: true),
                  onChanged: (_) => _edited(),
                ),
              ),
              IconButton(tooltip: 'Remove this row', icon: const Icon(Icons.close_rounded, color: AppColors.textMuted), onPressed: widget.onRemove),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextField(
              controller: _name,
              style: AppText.input,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Name', isDense: true),
              onChanged: (_) => _edited(),
            ),
          ),
          if (row.message != null && widget.needsLook) ...[
            const SizedBox(height: 8),
            Text(row.message!, style: AppText.small.copyWith(color: AppColors.dangerText)),
          ],
          if (widget.needsLook && row.status == 'not_in_file')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _edited, child: const Text('It\'s correct')),
            ),
        ],
      ),
    );
  }

  Widget _plain(ExtractedRow row, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8, right: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.fullName, style: AppText.rowTitle),
                const SizedBox(height: 2),
                Text(row.rollNumber, style: AppText.monoSmall.copyWith(color: AppColors.textMuted)),
                if (row.isSkipped && row.message != null) Text(row.message!, style: AppText.small.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          trailing ?? IconButton(tooltip: 'Remove this row', icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted), onPressed: widget.onRemove),
        ],
      ),
    );
  }
}
