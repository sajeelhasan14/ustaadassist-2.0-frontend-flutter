import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/card_list.dart';
import '../../../shared/widgets/empty_note.dart';
import '../../../shared/widgets/hero_panel.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../courses/data/courses_api.dart';
import '../../results/widgets/download_buttons.dart';
import '../../results/data/results_api.dart';
import '../data/attendance_api.dart';

/// Who is short of attendance, and every student's percentage.
class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key, required this.course, required this.section});

  final Course course;
  final Section section;

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  late Future<AttendanceReport> _data = AttendanceApi.report(widget.section.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Report · Section ${widget.section.name}')),
      body: SafeArea(
        child: AsyncBody<AttendanceReport>(
          future: _data,
          onRetry: () => setState(() { _data = AttendanceApi.report(widget.section.id); }),
          builder: (context, report) {
            if (report.held == 0) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: EmptyNote(title: 'Nothing to report yet', message: 'Percentages appear once the first class is marked.'),
              );
            }
            final short = report.short;
            final others = report.students.where((item) => !item.shortage).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                HeroPanel(
                  label: '${report.held} ${report.held == 1 ? 'CLASS' : 'CLASSES'} HELD',
                  tone: short.isEmpty ? HeroTone.green : HeroTone.warning,
                  child: Text(
                    short.isEmpty ? 'Nobody is short' : '${short.length} below ${report.min}%',
                    style: AppText.heroTitle.copyWith(color: AppColors.onGreen, fontSize: 30),
                  ),
                ),
                if (short.isNotEmpty) ..._block('SHORT OF ATTENDANCE', short),
                if (others.isNotEmpty) ..._block('EVERYONE ELSE', others),
                const SizedBox(height: 20),
                DownloadButtons(course: widget.course, section: widget.section, kind: SheetKind.attendance),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _block(String label, List<StudentAttendance> items) => [
        const SizedBox(height: 20),
        Text(label, style: AppText.label),
        const SizedBox(height: 10),
        CardList(children: [for (final item in items) _Row(item: item)]),
      ];
}

class _Row extends StatelessWidget {
  const _Row({required this.item});

  final StudentAttendance item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.fullName, style: AppText.rowTitle),
                const SizedBox(height: 2),
                Text('${item.rollNumber} · ${item.present} of ${item.marked}', style: AppText.monoSmall.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusPill(item.percentage == null ? '–' : '${item.percentage}%', tone: item.shortage ? PillTone.danger : PillTone.success),
        ],
      ),
    );
  }
}
