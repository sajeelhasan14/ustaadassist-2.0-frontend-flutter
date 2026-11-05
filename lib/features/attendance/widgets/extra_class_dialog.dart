import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../data/attendance_api.dart';

/// Adds a make-up class outside the timetable. Pops true once it's saved.
class ExtraClassDialog extends StatefulWidget {
  const ExtraClassDialog({super.key, required this.sectionId});

  final String sectionId;

  @override
  State<ExtraClassDialog> createState() => _ExtraClassDialogState();
}

class _ExtraClassDialogState extends State<ExtraClassDialog> {
  String? _date;
  String _start = '09:00';
  String _end = '10:00';
  bool _busy = false;
  String? _error;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = isoDate(picked));
  }

  Future<void> _pickTime({required bool start}) async {
    final parts = (start ? _start : _end).split(':');
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
    if (picked == null) return;
    final text = timeText(picked.hour, picked.minute);
    setState(() => start ? _start = text : _end = text);
  }

  Future<void> _save() async {
    if (_date == null) {
      setState(() => _error = 'Choose a date.');
      return;
    }
    if (_end.compareTo(_start) <= 0) {
      setState(() => _error = 'A class must end after it starts.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AttendanceApi.addExtra(widget.sectionId, date: _date!, startTime: _start, endTime: _end);
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
      title: Text('Extra class', style: AppText.cardTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(onPressed: _pickDate, child: Text(_date == null ? 'Choose a date' : longDate(_date!))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => _pickTime(start: true), child: Text(_start))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => _pickTime(start: false), child: Text(_end))),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: AppText.small.copyWith(color: AppColors.dangerText)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Add')),
      ],
    );
  }
}
