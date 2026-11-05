import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/empty_note.dart';
import '../../../shared/widgets/prompts.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../courses/data/courses_api.dart';
import '../data/marks_api.dart';

/// Entering marks one student at a time on a number pad, so the teacher's eyes
/// stay on the paper. Marks save in the background and the next student is
/// ready at once. Design: Night screen 29.
class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key, required this.assessmentId, required this.section});

  final String assessmentId;
  final Section section;

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  late Future<MarksSheet> _data = MarksApi.sheet(widget.assessmentId, widget.section.id);

  int _index = 0;
  String _typed = '';

  /// Marks waiting to reach the server. Kept until a save succeeds, so a failed
  /// request loses nothing: the next save simply sends them again.
  final Map<String, num?> _waiting = {};
  Future<void>? _sending; // the save in progress, so leaving can wait for it
  String? _saveError;

  void _show(MarksSheet sheet, int index) {
    setState(() {
      _index = index;
      final marks = sheet.students[index].marks;
      _typed = marks == null ? '' : markText(marks);
    });
  }

  void _press(String key) {
    setState(() {
      if (key == '.' && (_typed.contains('.') || _typed.isEmpty)) return;
      // Marks are stored with two decimals at most.
      final dot = _typed.indexOf('.');
      if (dot >= 0 && _typed.length - dot > 2) return;
      // "0" then "7" means 7, not 07.
      _typed = _typed == '0' && key != '.' ? key : _typed + key;
    });
  }

  void _backspace() {
    if (_typed.isNotEmpty) setState(() => _typed = _typed.substring(0, _typed.length - 1));
  }

  /// Starts sending, or joins the save already running, so there's only ever one at a time.
  Future<void> _flush(MarksSheet sheet) => _sending ??= _sendAll(sheet).whenComplete(() => _sending = null);

  /// Sends everything waiting. Marks entered during a request go in the next one.
  Future<void> _sendAll(MarksSheet sheet) async {
    while (_waiting.isNotEmpty) {
      final batch = Map<String, num?>.of(_waiting);
      try {
        await MarksApi.save(sheet.id, batch);
        // Only forget what was sent and hasn't been changed since.
        batch.forEach((id, value) {
          if (_waiting[id] == value) _waiting.remove(id);
        });
        _saveError = null;
      } catch (error) {
        _saveError = '$error';
        break;
      }
    }
    if (mounted) setState(() {});
  }

  void _record(MarksSheet sheet, num? value) {
    final student = sheet.students[_index];
    if (student.marks != value) {
      student.marks = value;
      _waiting[student.id] = value;
      _flush(sheet);
    }
  }

  void _saveAndNext(MarksSheet sheet) {
    final value = num.tryParse(_typed);
    // An empty pad leaves the student as they were, so skipping someone is one tap.
    if (value != null) _record(sheet, value);
    _advance(sheet);
  }

  void _absent(MarksSheet sheet) {
    _record(sheet, null);
    _advance(sheet);
  }

  void _advance(MarksSheet sheet) {
    if (_index < sheet.students.length - 1) {
      _show(sheet, _index + 1);
    } else {
      _leave(sheet);
    }
  }

  /// Leaving waits for the last marks. If they can't be saved, the teacher decides.
  Future<void> _leave(MarksSheet? sheet) async {
    if (sheet != null) {
      await _flush(sheet);
      if (!mounted) return;
      if (_waiting.isNotEmpty) {
        final leave = await confirmAction(
          context,
          title: "${_waiting.length} marks aren't saved",
          message: _saveError ?? 'Please check your connection.',
          action: 'Leave anyway',
        );
        if (!leave || !mounted) return;
      }
    }
    Navigator.of(context).pop(true);
  }

  MarksSheet? _loaded;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(_loaded);
      },
      child: Scaffold(
        appBar: AppBar(title: FutureBuilder(future: _data, builder: (_, snapshot) => Text(snapshot.data?.name ?? 'Marks'))),
        body: SafeArea(
          child: AsyncBody<MarksSheet>(
            future: _data,
            onRetry: () => setState(() { _data = MarksApi.sheet(widget.assessmentId, widget.section.id); }),
            builder: (context, sheet) {
              if (sheet.students.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: EmptyNote(title: 'No students yet', message: 'Add this section\'s class list first.'),
                );
              }
              if (_loaded == null) {
                _loaded = sheet;
                final first = sheet.students.indexWhere((student) => student.marks == null);
                _index = first < 0 ? 0 : first; // pick up where the teacher stopped
                final marks = sheet.students[_index].marks;
                _typed = marks == null ? '' : markText(marks);
              }
              return _EntryView(
                sheet: sheet,
                index: _index,
                typed: _typed,
                saveError: _saveError,
                onStudent: (index) => _show(sheet, index),
                onKey: _press,
                onBackspace: _backspace,
                onAbsent: () => _absent(sheet),
                onNext: () => _saveAndNext(sheet),
                onRetrySave: () => _flush(sheet),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EntryView extends StatelessWidget {
  const _EntryView({
    required this.sheet,
    required this.index,
    required this.typed,
    required this.saveError,
    required this.onStudent,
    required this.onKey,
    required this.onBackspace,
    required this.onAbsent,
    required this.onNext,
    required this.onRetrySave,
  });

  final MarksSheet sheet;
  final int index;
  final String typed;
  final String? saveError;
  final ValueChanged<int> onStudent;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onAbsent;
  final VoidCallback onNext;
  final VoidCallback onRetrySave;

  @override
  Widget build(BuildContext context) {
    final student = sheet.students[index];
    final value = num.tryParse(typed);
    final tooHigh = value != null && value > sheet.maxMarks;
    final last = index == sheet.students.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            decoration: BoxDecoration(color: tooHigh ? AppColors.danger : AppColors.green, borderRadius: BorderRadius.circular(AppRadius.card)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(student.rollNumber, style: AppText.monoSmall.copyWith(color: AppColors.onGreenSoft))),
                    Text('${index + 1} / ${sheet.students.length}', style: AppText.monoSmall.copyWith(color: AppColors.onGreenSoft)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(student.fullName, style: AppText.rowTitle.copyWith(color: AppColors.onGreen, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(typed.isEmpty ? '–' : typed, style: AppText.bigNumber.copyWith(color: AppColors.onGreen)),
                    const SizedBox(width: 6),
                    Text('/ ${markText(sheet.maxMarks)}', style: AppText.cardTitle.copyWith(color: AppColors.onGreenSoft)),
                    const Spacer(),
                    if (tooHigh) Text('Too high', style: AppText.rowTitle.copyWith(color: AppColors.onGreen)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sheet.students.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, position) => _StudentChip(
                row: sheet.students[position],
                selected: position == index,
                onTap: () => onStudent(position),
              ),
            ),
          ),
          if (saveError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(child: Text(saveError!, style: AppText.small.copyWith(color: AppColors.dangerText))),
                  GestureDetector(onTap: onRetrySave, child: const StatusPill('Try again', tone: PillTone.danger)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              children: [
                for (final keys in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  _KeyRow(children: [for (final key in keys) _Key(label: key, onTap: () => onKey(key))]),
                _KeyRow(
                  children: [
                    _Key(label: '.', onTap: () => onKey('.')),
                    _Key(label: '0', onTap: () => onKey('0')),
                    _Key(icon: Icons.backspace_outlined, label: 'Delete', onTap: onBackspace),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.dangerTint, foregroundColor: AppColors.dangerText, padding: const EdgeInsets.symmetric(horizontal: 18)),
                onPressed: onAbsent,
                child: const Text('Absent'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(onPressed: tooHigh ? null : onNext, child: Text(last ? 'Save and finish' : 'Save and next')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.inner),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.inner),
            onTap: onTap,
            child: Center(
              child: icon == null
                  ? Text(label, style: AppText.cardTitle.copyWith(fontSize: 24))
                  : Icon(icon, semanticLabel: label, color: AppColors.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentChip extends StatelessWidget {
  const _StudentChip({required this.row, required this.selected, required this.onTap});

  final MarkRow row;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.onGreen : AppColors.text;
    final tail = row.rollNumber.length > 4 ? row.rollNumber.substring(row.rollNumber.length - 4) : row.rollNumber;
    return Material(
      color: selected ? AppColors.green : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(tail, style: AppText.monoSmall.copyWith(color: selected ? AppColors.onGreenSoft : AppColors.textMuted)),
              Text(row.marks == null ? '–' : markText(row.marks!), style: AppText.rowTitle.copyWith(color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}
