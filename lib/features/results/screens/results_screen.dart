import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/card_list.dart';
import '../../../shared/widgets/empty_note.dart';
import '../../../shared/widgets/hero_panel.dart';
import '../../../shared/widgets/prompts.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../courses/data/courses_api.dart';
import '../data/results_api.dart';
import '../widgets/download_buttons.dart';
import 'sheet_details_screen.dart';

/// The result sheet, which appears by itself from the marks. Nothing here is
/// typed in or stored: change a mark and this follows.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.course, required this.section});

  final Course course;
  final Section section;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late Future<ResultSheet> _data = ResultsApi.load(widget.section.id);

  void _reload() => setState(() { _data = ResultsApi.load(widget.section.id); });

  Future<void> _details(ResultSheet sheet) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SheetDetailsScreen(courseId: widget.course.id, sheet: sheet)),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results · Section ${widget.section.name}')),
      body: SafeArea(
        child: AsyncBody<ResultSheet>(
          future: _data,
          onRetry: _reload,
          builder: (context, sheet) {
            if (sheet.students.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: EmptyNote(title: 'No results yet', message: 'Add students and enter marks, and the sheet builds itself.'),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                HeroPanel(
                  label: sheet.incomplete > 0 ? '${sheet.incomplete} NOT FINAL' : 'OUT OF ${markText(sheet.totalMarks)}',
                  tone: sheet.incomplete > 0 ? HeroTone.warning : HeroTone.green,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${sheet.passed} passed', style: AppText.heroTitle.copyWith(color: AppColors.onGreen, fontSize: 34)),
                      const SizedBox(height: 6),
                      Text(
                        '${sheet.failed} failed · ${sheet.absent} absent',
                        style: AppText.mono.copyWith(color: AppColors.onGreen),
                      ),
                      if (sheet.incomplete > 0) ...[
                        const SizedBox(height: 6),
                        Text('Some students are still missing marks.', style: AppText.small.copyWith(color: AppColors.onGreen)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('DOWNLOADS', style: AppText.label),
                const SizedBox(height: 10),
                for (final kind in SheetKind.values) ...[
                  DownloadButtons(course: widget.course, section: widget.section, kind: kind),
                  const SizedBox(height: 14),
                ],
                OutlinedButton(onPressed: () => _details(sheet), child: const Text('Sheet details')),
                const SizedBox(height: 20),
                Text('${sheet.studentCount} STUDENTS', style: AppText.label),
                const SizedBox(height: 10),
                CardList(children: [for (final row in sheet.students) _Row(row: row, hasLab: sheet.hasLab)]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.hasLab});

  final ResultRow row;
  final bool hasLab;

  @override
  Widget build(BuildContext context) {
    final split = hasLab && !row.absent ? ' · Th ${markText(row.theory ?? 0)} + Lab ${markText(row.lab ?? 0)}' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.fullName, style: AppText.rowTitle),
                const SizedBox(height: 2),
                Text('${row.rollNumber}$split', style: AppText.monoSmall.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(
                  row.missing > 0 && !row.absent ? '${row.remarks} · ${row.missing} marks missing' : row.remarks,
                  style: AppText.small.copyWith(color: row.failed ? AppColors.dangerText : AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(row.total == null ? '–' : markText(row.total!), style: AppText.mono),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: StatusPill(row.grade ?? 'Abs', tone: row.absent ? PillTone.warning : (row.grade == 'F' ? PillTone.danger : PillTone.success)),
            ),
          ),
        ],
      ),
    );
  }
}
