import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/step_scaffold.dart';
import '../data/results_api.dart';

/// The lines printed at the top of the result sheet. They're typed once: a new
/// course copies them from the teacher's latest one. Pops true once saved.
class SheetDetailsScreen extends StatefulWidget {
  const SheetDetailsScreen({super.key, required this.courseId, required this.sheet});

  final String courseId;
  final ResultSheet sheet;

  @override
  State<SheetDetailsScreen> createState() => _SheetDetailsScreenState();
}

class _SheetDetailsScreenState extends State<SheetDetailsScreen> {
  /// Field name → label. The last four print the University of Karachi lines when left blank.
  static const _fields = {
    'department': 'Department',
    'majorDepartment': 'Major department',
    'className': 'Class',
    'year': 'Year',
    'semester': 'Semester',
    'examDate': 'Date of examination',
    'university': 'University',
    'examination': 'Examination',
    'faculty': 'Faculty',
    'programme': 'Programme',
  };

  late final _creditHours = TextEditingController(text: widget.sheet.creditHours);
  late final Map<String, TextEditingController> _text = {
    for (final key in _fields.keys) key: TextEditingController(text: widget.sheet.header.values[key]),
  };
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _creditHours.dispose();
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_creditHours.text.trim().isEmpty) {
      setState(() => _error = 'Enter the credit hours, e.g. 3+0.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ResultsApi.saveDetails(
        widget.courseId,
        creditHours: _creditHours.text.trim(),
        header: {
          for (final entry in _text.entries)
            if (entry.value.text.trim().isNotEmpty) entry.key: entry.value.text.trim(),
        },
      );
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
    return StepScaffold(
      title: 'Sheet details',
      step: widget.sheet.code,
      headingTop: 'Printed at',
      headingBottom: 'the top.',
      subtitle: 'Type these once. Your next course copies them. Blank university lines print the University of Karachi ones.',
      error: _error,
      buttonLabel: _busy ? 'Saving…' : 'Save details',
      onPressed: _busy ? null : _save,
      children: [
        TextField(controller: _creditHours, style: AppText.mono, decoration: const InputDecoration(labelText: 'Credit hours')),
        for (final entry in _fields.entries) ...[
          const SizedBox(height: 10),
          TextField(controller: _text[entry.key], style: AppText.input, decoration: InputDecoration(labelText: entry.value)),
        ],
      ],
    );
  }
}
