import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/card_list.dart';
import '../../../shared/widgets/empty_note.dart';
import '../../../shared/widgets/prompts.dart';
import '../../courses/data/courses_api.dart';
import '../data/students_api.dart';
import 'student_details_screen.dart';
import 'capture_list_screen.dart';

/// The class list of one section.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, required this.section});

  final Section section;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  late Future<List<Student>> _data = StudentsApi.list(widget.section.id);
  String _search = '';

  void _reload() => setState(() { _data = StudentsApi.list(widget.section.id); });

  Future<void> _import() async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CaptureListScreen(section: widget.section)));
    if (added == true) _reload();
  }

  Future<void> _edit([Student? student]) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => StudentDialog(sectionId: widget.section.id, student: student));
    if (saved == true) _reload();
  }

  /// Opens the student's details, then reloads: their name may have been fixed there.
  Future<void> _open(Student student) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentDetailsScreen(section: widget.section, student: student)));
    if (mounted) _reload();
  }

  Future<void> _remove(Student student) async {
    final agreed = await confirmAction(
      context,
      title: 'Remove ${student.fullName}?',
      message: 'They leave this section, and their attendance and marks here stop counting. Their other courses stay.',
      action: 'Remove',
    );
    if (!agreed) return;
    try {
      await StudentsApi.remove(widget.section.id, student.id);
      _reload();
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Students · Section ${widget.section.name}'),
        actions: [IconButton(tooltip: 'Add one student', icon: const Icon(Icons.person_add_alt_rounded), onPressed: _edit)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.onGreen,
        onPressed: _import,
        icon: const Icon(Icons.document_scanner_outlined),
        label: Text('Import list', style: AppText.button),
      ),
      body: SafeArea(
        child: AsyncBody<List<Student>>(
          future: _data,
          onRetry: _reload,
          builder: (context, students) {
            if (students.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: EmptyNote(
                  title: 'No students yet',
                  message: 'Photograph the class list or pick a PDF or Excel file. Nothing to type.',
                  action: 'Import list',
                  onAction: _import,
                ),
              );
            }
            final query = _search.toLowerCase();
            final shown = students
                .where((item) => item.fullName.toLowerCase().contains(query) || item.rollNumber.toLowerCase().contains(query))
                .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
              children: [
                TextField(
                  style: AppText.input,
                  decoration: const InputDecoration(hintText: 'Search name or seat number', prefixIcon: Icon(Icons.search_rounded)),
                  onChanged: (text) => setState(() => _search = text),
                ),
                const SizedBox(height: 16),
                Text('${students.length} STUDENTS', style: AppText.label),
                const SizedBox(height: 10),
                if (shown.isEmpty)
                  Text('Nobody matches.', style: AppText.body.copyWith(color: AppColors.textMuted))
                else
                  CardList(children: [for (final student in shown) _Row(student: student, onOpen: () => _open(student), onRemove: () => _remove(student))]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.student, required this.onOpen, required this.onRemove});

  final Student student;
  final VoidCallback onOpen; // the student's details
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.fullName, style: AppText.rowTitle),
                  const SizedBox(height: 2),
                  Text(student.rollNumber, style: AppText.monoSmall.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove ${student.fullName}',
              icon: Icon(Icons.person_remove_outlined, size: 20, color: AppColors.textMuted),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// Adds one forgotten student, or fixes a student's details. Pops true once saved.
class StudentDialog extends StatefulWidget {
  const StudentDialog({super.key, required this.sectionId, this.student});

  final String sectionId;
  final Student? student;

  @override
  State<StudentDialog> createState() => StudentDialogState();
}

class StudentDialogState extends State<StudentDialog> {
  late final _roll = TextEditingController(text: widget.student?.rollNumber);
  late final _name = TextEditingController(text: widget.student?.fullName);
  late final _father = TextEditingController(text: widget.student?.fatherName);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _roll.dispose();
    _name.dispose();
    _father.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final roll = _roll.text.trim();
    final name = _name.text.trim();
    final father = _father.text.trim().isEmpty ? null : _father.text.trim();
    if (roll.isEmpty || name.isEmpty) {
      setState(() => _error = 'Enter the seat number and name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final student = widget.student;
      if (student == null) {
        await StudentsApi.add(widget.sectionId, rollNumber: roll, fullName: name, fatherName: father);
      } else {
        await StudentsApi.update(student.id, rollNumber: roll, fullName: name, fatherName: father);
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
      backgroundColor: AppColors.sheet,
      title: Text(widget.student == null ? 'Add a student' : 'Edit student', style: AppText.cardTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _roll,
              textCapitalization: TextCapitalization.characters,
              style: AppText.mono,
              decoration: const InputDecoration(labelText: 'Seat number'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.characters,
              style: AppText.input,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _father,
              textCapitalization: TextCapitalization.characters,
              style: AppText.input,
              decoration: const InputDecoration(labelText: "Father's name (optional)"),
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
