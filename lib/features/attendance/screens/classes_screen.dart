import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/glass_menu.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/card_list.dart';
import '../../../shared/widgets/empty_note.dart';
import '../../../shared/widgets/hero_panel.dart';
import '../../../shared/widgets/prompts.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../courses/data/courses_api.dart';
import '../data/attendance_api.dart';
import '../widgets/extra_class_dialog.dart';
import 'attendance_report_screen.dart';
import 'take_attendance_screen.dart';

/// Every class of one section, with the ones that need attention first.
class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key, required this.course, required this.section});

  final Course course;
  final Section section;

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  late Future<SectionPlan> _data = CoursesApi.plan(widget.section.id);

  void _reload() => setState(() { _data = CoursesApi.plan(widget.section.id); });

  Future<void> _take(ClassSession session) async {
    final ref = ClassRef(sectionId: widget.section.id, date: session.date, startTime: session.startTime, title: widget.course.title);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TakeAttendanceScreen(classRef: ref)));
    if (mounted) _reload();
  }

  /// Runs a change to a class, then refreshes the list. A failure is shown, not swallowed.
  Future<void> _change(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) _reload();
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  Future<void> _cancel(ClassSession session) async {
    final agreed = await confirmAction(
      context,
      title: 'Cancel this class?',
      message: '${weekdayName(session.date)} ${shortDate(session.date)} at ${session.startTime}. The plan moves its topic to the next class.',
      action: 'Cancel class',
    );
    if (agreed) await _change(() => AttendanceApi.cancel(widget.section.id, session));
  }

  Future<void> _addExtra() async {
    final added = await showDialog<bool>(context: context, builder: (_) => ExtraClassDialog(sectionId: widget.section.id));
    if (added == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance · Section ${widget.section.name}'),
        actions: [
          IconButton(
            tooltip: 'Attendance report',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AttendanceReportScreen(course: widget.course, section: widget.section)),
            ),
          ),
          IconButton(tooltip: 'Add an extra class', icon: const Icon(Icons.add_rounded), onPressed: _addExtra),
        ],
      ),
      body: SafeArea(
        child: AsyncBody<SectionPlan>(
          future: _data,
          onRetry: _reload,
          builder: (context, plan) => ClassesView(
            plan: plan,
            onTake: _take,
            onCancel: _cancel,
            onRestore: (session) => _change(() => AttendanceApi.restore(session.id!)),
          ),
        ),
      ),
    );
  }
}

class ClassesView extends StatelessWidget {
  const ClassesView({super.key, required this.plan, required this.onTake, required this.onCancel, required this.onRestore});

  final SectionPlan plan;
  final ValueChanged<ClassSession> onTake;
  final ValueChanged<ClassSession> onCancel;
  final ValueChanged<ClassSession> onRestore;

  @override
  Widget build(BuildContext context) {
    final today = plan.today;
    final sessions = plan.sessions;
    if (sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: EmptyNote(title: 'No classes yet', message: 'Set this section\'s timetable in course settings, and its classes appear here.'),
      );
    }
    // Oldest first, so the teacher clears the backlog in the order it happened.
    final toMark = sessions.where((item) => item.status == 'planned' && item.date.compareTo(today) <= 0).toList();
    final upcoming = sessions.where((item) => item.date.compareTo(today) > 0 && item.status != 'held').toList();
    final past = sessions.where((item) => !toMark.contains(item) && !upcoming.contains(item)).toList().reversed.toList();
    final next = toMark.lastOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        if (next != null)
          HeroPanel(
            label: next.date == today ? 'TODAY · ${next.startTime}' : '${toMark.length} NOT MARKED',
            tone: next.date == today ? HeroTone.green : HeroTone.warning,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    next.topics.firstOrNull?.title ?? '${weekdayName(next.date)} ${shortDate(next.date)}',
                    style: AppText.cardTitle.copyWith(color: AppColors.onGreen),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.onGreen, foregroundColor: AppColors.green),
                  onPressed: () => onTake(next),
                  child: const Text('Take'),
                ),
              ],
            ),
          ),
        if (toMark.isNotEmpty) ..._block('TO MARK', toMark),
        if (upcoming.isNotEmpty) ..._block('UPCOMING', upcoming),
        if (past.isNotEmpty) ..._block('PAST', past),
      ],
    );
  }

  List<Widget> _block(String label, List<ClassSession> items) => [
        const SizedBox(height: 20),
        Text(label, style: AppText.label),
        const SizedBox(height: 10),
        CardList(
          children: [
            for (final item in items) _ClassRow(session: item, today: plan.today, onTake: onTake, onCancel: onCancel, onRestore: onRestore),
          ],
        ),
      ];
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.session, required this.today, required this.onTake, required this.onCancel, required this.onRestore});

  final ClassSession session;
  final String today;
  final ValueChanged<ClassSession> onTake;
  final ValueChanged<ClassSession> onCancel;
  final ValueChanged<ClassSession> onRestore;

  bool get _canMark => session.date.compareTo(today) <= 0 && (session.status == 'planned' || session.status == 'held');

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (session.status) {
      'held' => ('${session.present} present', PillTone.success),
      'cancelled' => ('Cancelled', PillTone.danger),
      'off_day' => ('Off day', PillTone.setup),
      _ => _canMark ? ('To mark', PillTone.warning) : ('Planned', PillTone.neutral),
    };
    final detail = session.offDayName ?? session.topics.map((topic) => topic.title).join(', ');
    final struck = session.status == 'cancelled' || session.status == 'off_day';
    return InkWell(
      onTap: _canMark ? () => onTake(session) : null,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10, right: 4),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(weekdayName(session.date), style: AppText.mono),
                  Text(shortDate(session.date), style: AppText.monoSmall.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${session.startTime}${session.extra ? ' · Extra' : ''}',
                    style: AppText.rowTitle.copyWith(
                      color: struck ? AppColors.textMuted : AppColors.text,
                      decoration: struck ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (detail.isNotEmpty) Text(detail, style: AppText.small.copyWith(color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Shrinks rather than overflows on a small phone or with large system text.
            Flexible(flex: 2, child: FittedBox(fit: BoxFit.scaleDown, child: StatusPill(label, tone: tone))),
            _Menu(session: session, onCancel: onCancel, onRestore: onRestore),
          ],
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.session, required this.onCancel, required this.onRestore});

  final ClassSession session;
  final ValueChanged<ClassSession> onCancel;
  final ValueChanged<ClassSession> onRestore;

  @override
  Widget build(BuildContext context) {
    // An off day isn't the teacher's to cancel, and a held class already happened.
    if (session.status == 'off_day' || session.status == 'held') return const SizedBox(width: 12);
    final cancelled = session.status == 'cancelled';
    return GlassMenuButton(
      tooltip: 'More',
      items: [
        cancelled
            ? GlassMenuItem('Restore class', Icons.restore_rounded, () => onRestore(session))
            : GlassMenuItem('Cancel class', Icons.event_busy_rounded, () => onCancel(session)),
      ],
    );
  }
}
