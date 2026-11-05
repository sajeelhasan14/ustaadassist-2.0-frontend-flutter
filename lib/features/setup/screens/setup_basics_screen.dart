import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/step_scaffold.dart';
import '../data/setup_api.dart';
import '../widgets/timetable_editor.dart';
import 'setup_topics_screen.dart';

/// Step 1: name, dates and class days. Design: Night screen 25.
class SetupBasicsScreen extends StatefulWidget {
  const SetupBasicsScreen({super.key});

  @override
  State<SetupBasicsScreen> createState() => _SetupBasicsScreenState();
}

class _SetupBasicsScreenState extends State<SetupBasicsScreen> {
  final _title = TextEditingController();
  final _code = TextEditingController();
  final List<ClassSlot> _slots = [];
  String? _start;
  String? _end;
  bool _busy = false;
  String? _error;

  /// Kept after the course is saved, so pressing Next again after a failed
  /// timetable save doesn't try to create the same course twice.
  SetupProgress? _saved;

  @override
  void initState() {
    super.initState();
    _prefillDates();
  }

  /// Every course in a term shares its dates, so the teacher usually just accepts these.
  Future<void> _prefillDates() async {
    try {
      final latest = await SetupApi.latestSemester();
      if (latest == null || !mounted) return;
      setState(() {
        _start ??= latest.startDate;
        _end ??= latest.endDate;
      });
    } catch (_) {
      // Only a convenience: the teacher can still pick the dates.
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final current = DateTime.tryParse((start ? _start : _end) ?? '') ?? DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: current, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked == null) return;
    setState(() => start ? _start = isoDate(picked) : _end = isoDate(picked));
  }

  String? _problem() {
    if (_title.text.trim().isEmpty || _code.text.trim().isEmpty) return 'Enter the course name and code.';
    if (_start == null || _end == null) return 'Choose when the semester starts and ends.';
    if (_end!.compareTo(_start!) < 0) return 'The end date must be after the start date.';
    if (_slots.isEmpty) return 'Choose at least one class day.';
    if (_slots.any((slot) => slot.endTime.compareTo(slot.startTime) <= 0)) return 'A class must end after it starts.';
    return null;
  }

  Future<void> _next() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = _saved ??
          await SetupApi.createCourse(
            semesterId: await SetupApi.semesterFor(_start!, _end!),
            title: _title.text.trim(),
            code: _code.text.trim(),
          );
      _saved = saved;
      await SetupApi.saveTimetable(saved.sectionId, _slots);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SetupTopicsScreen(progress: saved)));
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
      title: 'New course',
      step: '1 / 3',
      headingTop: 'The',
      headingBottom: 'basics.',
      subtitle: 'Everything else can wait until you need it.',
      error: _error,
      buttonLabel: _busy ? 'Saving…' : 'Next: add topics',
      onPressed: _busy ? null : _next,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: TextField(
                controller: _title,
                enabled: _saved == null,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: AppText.input,
                decoration: const InputDecoration(labelText: 'Course name'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _code,
                enabled: _saved == null,
                textCapitalization: TextCapitalization.characters,
                style: AppText.mono,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: ValueBox(label: 'Starts', value: _start == null ? 'Choose' : longDate(_start!), onTap: _saved == null ? () => _pickDate(start: true) : null)),
            const SizedBox(width: 10),
            Expanded(child: ValueBox(label: 'Ends', value: _end == null ? 'Choose' : longDate(_end!), onTap: _saved == null ? () => _pickDate(start: false) : null)),
          ],
        ),
        const SizedBox(height: 20),
        Text('CLASS DAYS', style: AppText.label),
        const SizedBox(height: 10),
        TimetableEditor(slots: _slots, onChanged: () => setState(() {})),
      ],
    );
  }
}
