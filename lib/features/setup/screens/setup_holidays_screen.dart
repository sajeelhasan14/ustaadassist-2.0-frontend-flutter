import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../../shared/widgets/step_scaffold.dart';
import '../../courses/screens/course_screen.dart';
import '../data/setup_api.dart';

/// Step 3: public holidays are already in, so the teacher only unticks any
/// their university teaches on. Design: Night screen 27.
/// With [standalone] it's opened from course settings and simply closes.
class SetupHolidaysScreen extends StatefulWidget {
  const SetupHolidaysScreen({super.key, required this.progress, this.standalone = false});

  final SetupProgress progress;
  final bool standalone;

  @override
  State<SetupHolidaysScreen> createState() => _SetupHolidaysScreenState();
}

class _SetupHolidaysScreenState extends State<SetupHolidaysScreen> {
  late Future<List<OffDay>> _loading = _load();
  List<OffDay> _days = [];
  final Set<String> _unticked = {};
  bool _busy = false;
  String? _error;

  Future<List<OffDay>> _load() async {
    final days = await SetupApi.offDays(widget.progress.semesterId);
    _days = days;
    return days;
  }

  Future<void> _addHoliday() async {
    final added = await showDialog<OffDay>(context: context, builder: (_) => const _AddHolidayDialog());
    if (added == null) return;
    setState(() {
      _days = [..._days, added]..sort((a, b) => a.startDate.compareTo(b.startDate));
    });
  }

  /// An Islamic holiday's date is a calculation until the moon is sighted, so it can move a day.
  Future<void> _shift(OffDay day) async {
    final days = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('A day earlier', style: AppText.rowTitle), onTap: () => Navigator.of(context).pop(-1)),
            ListTile(title: Text('Confirmed on ${shortDate(day.startDate)}', style: AppText.rowTitle), onTap: () => Navigator.of(context).pop(0)),
            ListTile(title: Text('A day later', style: AppText.rowTitle), onTap: () => Navigator.of(context).pop(1)),
          ],
        ),
      ),
    );
    if (days == null) return;
    try {
      final moved = await SetupApi.shiftOffDay(day.id, days);
      if (!mounted) return;
      setState(() {
        _days = [for (final item in _days) item.id == moved.id ? moved : item]..sort((a, b) => a.startDate.compareTo(b.startDate));
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  /// Nothing is removed until here, so a mis-tap can simply be ticked back on.
  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Future.wait(_unticked.map(SetupApi.removeOffDay));
      if (!mounted) return;
      if (widget.standalone) {
        Navigator.of(context).pop();
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CourseScreen(course: widget.progress.course)),
      );
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
      title: widget.progress.course.title,
      step: widget.standalone ? 'Holidays' : '3 / 3',
      headingTop: 'Any of these',
      headingBottom: 'not apply?',
      subtitle: 'Public holidays are already in, and they apply to all your classes. Untick any your university still teaches on.',
      error: _error,
      buttonLabel: _busy ? 'Saving…' : (widget.standalone ? 'Save holidays' : 'Generate my plan'),
      onPressed: _busy ? null : _finish,
      children: [
        FutureBuilder<List<OffDay>>(
          future: _loading,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(message: '${snapshot.error}', onRetry: () => setState(() { _loading = _load(); }));
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
            }
            if (_days.isEmpty) {
              return Text('No public holidays fall in this semester.', style: AppText.body.copyWith(color: AppColors.textMuted));
            }
            return Container(
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.inner)),
              child: Column(
                children: [
                  for (final (index, day) in _days.indexed) ...[
                    if (index > 0) const Divider(),
                    _HolidayRow(
                      day: day,
                      ticked: !_unticked.contains(day.id),
                      onChanged: (ticked) => setState(() => ticked ? _unticked.remove(day.id) : _unticked.add(day.id)),
                      onShift: () => _shift(day),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _addHoliday, icon: const Icon(Icons.add_rounded), label: const Text('Add a university holiday')),
      ],
    );
  }
}

class _HolidayRow extends StatelessWidget {
  const _HolidayRow({required this.day, required this.ticked, required this.onChanged, required this.onShift});

  final OffDay day;
  final bool ticked;
  final ValueChanged<bool> onChanged;
  final VoidCallback onShift;

  @override
  Widget build(BuildContext context) {
    final muted = !ticked;
    return CheckboxListTile(
      value: ticked,
      onChanged: (value) => onChanged(value ?? false),
      activeColor: AppColors.green,
      checkColor: AppColors.onGreen,
      title: Row(
        children: [
          Text(shortDate(day.startDate), style: AppText.monoSmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              day.name,
              style: AppText.rowTitle.copyWith(
                color: muted ? AppColors.textMuted : AppColors.text,
                decoration: muted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (day.tentative)
            Semantics(
              button: true,
              label: 'Change the date of ${day.name}',
              excludeSemantics: true,
              child: GestureDetector(onTap: onShift, child: const StatusPill('Moon sighting')),
            ),
        ],
      ),
    );
  }
}

class _AddHolidayDialog extends StatefulWidget {
  const _AddHolidayDialog();

  @override
  State<_AddHolidayDialog> createState() => _AddHolidayDialogState();
}

class _AddHolidayDialogState extends State<_AddHolidayDialog> {
  final _name = TextEditingController();
  String? _date;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = isoDate(picked));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _date == null) {
      setState(() => _error = 'Enter a name and choose a date.');
      return;
    }
    setState(() => _busy = true);
    try {
      final day = await SetupApi.addOffDay(_name.text.trim(), _date!);
      if (mounted) Navigator.of(context).pop(day);
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
      title: Text('Add a holiday', style: AppText.cardTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: _name, style: AppText.input, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _pickDate, child: Text(_date == null ? 'Choose a date' : longDate(_date!))),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: AppText.small.copyWith(color: AppColors.dangerText)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Add')),
      ],
    );
  }
}
