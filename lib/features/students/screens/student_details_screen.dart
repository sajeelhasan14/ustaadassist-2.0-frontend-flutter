import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/celebrate.dart';
import '../../../shared/widgets/progress_shapes.dart';
import '../../../shared/widgets/prompts.dart';
import '../../courses/data/courses_api.dart';
import '../data/students_api.dart';
import 'students_screen.dart';

/// One student in one section: who they are, their attendance (with the days they
/// missed, for when a student disputes it) and their marks. Opened from the class list.
class StudentDetailsScreen extends StatefulWidget {
  const StudentDetailsScreen({super.key, required this.section, required this.student});

  final Section section;
  final Student student; // shown in the title straight away, before the rest loads

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  late Future<StudentDetails> _data = StudentsApi.details(widget.section.id, widget.student.id);

  void _reload() => setState(() { _data = StudentsApi.details(widget.section.id, widget.student.id); });

  /// The same edit box as the class list's "Add one student".
  Future<void> _edit(Student student) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => StudentDialog(sectionId: widget.section.id, student: student));
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Section ${widget.section.name}'),
        actions: [
          FutureBuilder<StudentDetails>(
            future: _data,
            builder: (context, snapshot) => IconButton(
              tooltip: 'Edit details',
              icon: const Icon(Icons.edit_outlined),
              onPressed: snapshot.hasData ? () => _edit(snapshot.data!.student) : null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AsyncBody<StudentDetails>(
          future: _data,
          onRetry: _reload,
          builder: (context, data) => StudentDetailsView(data: data),
        ),
      ),
    );
  }
}

/// Separate from the loading code so it can be tested with made-up data.
class StudentDetailsView extends StatelessWidget {
  const StudentDetailsView({super.key, required this.data});

  final StudentDetails data;

  @override
  Widget build(BuildContext context) {
    final student = data.student;
    final percentage = data.percentage;
    final absences = data.marked - data.present;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(student.fullName, style: AppText.screenTitle),
        const SizedBox(height: 4),
        Text(
          [student.rollNumber, if (student.fatherName != null) 'Father: ${student.fatherName}', if (data.email != null) data.email!].join(' · '),
          style: AppText.monoSmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 18),
        // Attendance: the ring and the giant %, violet when below the course's line.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppGlass.box(AppRadius.card),
          child: Row(
            children: [
              ProgressRing(
                value: (percentage ?? 0) / 100,
                colour: data.shortage ? AppColors.warning : null,
                child: Icon(data.shortage ? Icons.warning_amber_rounded : Icons.check_rounded, color: data.shortage ? AppColors.warningText : AppColors.greenText),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    percentage == null
                        ? Text('–', style: AppText.bigNumber)
                        : CountUp(percentage, style: AppText.bigNumber, suffix: '%', suffixStyle: AppText.rowTitle),
                    Text(
                      percentage == null
                          ? 'No class marked yet'
                          : '${data.present} of ${data.marked} classes · line ${markText(data.line)}%',
                      style: AppText.small.copyWith(color: AppColors.textMuted),
                    ),
                    if (data.shortage) ...[
                      const SizedBox(height: 4),
                      Text('Short of attendance', style: AppText.rowTitle.copyWith(color: AppColors.warningText, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(absences == 0 ? 'NO CLASSES MISSED' : 'MISSED $absences ${absences == 1 ? 'CLASS' : 'CLASSES'}', style: AppText.label),
        const SizedBox(height: 10),
        if (data.absentOn.isNotEmpty)
          // Small date chips, newest first: quick to read out to a student.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final day in data.absentOn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.dangerTint, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text('${shortDate(day.date)} · ${day.startTime}', style: AppText.pill.copyWith(color: AppColors.dangerText)),
                ),
            ],
          ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: Text('MARKS', style: AppText.label)),
            Text('${markText(data.total)} / ${markText(data.outOf)}', style: AppText.mono),
          ],
        ),
        const SizedBox(height: 10),
        if (data.marks.isEmpty)
          Text('No assessments in this course yet.', style: AppText.body.copyWith(color: AppColors.textMuted))
        else
          Container(
            decoration: AppGlass.box(AppRadius.inner),
            child: Column(
              children: [
                for (final (index, item) in data.marks.indexed) ...[
                  if (index > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(item.isLab ? '${item.name} · Lab' : item.name, style: AppText.rowTitle)),
                            Text(
                              item.marks == null ? '–  / ${markText(item.maxMarks)}' : '${markText(item.marks!)} / ${markText(item.maxMarks)}',
                              style: AppText.mono.copyWith(color: item.marks == null ? AppColors.textMuted : AppColors.text),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // A thin bar per score (approved with the 2026-11-09 look).
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.marks == null || item.maxMarks == 0 ? 0 : (item.marks! / item.maxMarks).clamp(0, 1).toDouble(),
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
