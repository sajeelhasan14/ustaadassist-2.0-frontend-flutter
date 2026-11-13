import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/hero_panel.dart';
import '../../../shared/widgets/prompts.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../assistant/screens/assistant_sheet.dart';
import '../../attendance/data/attendance_api.dart';
import '../../attendance/screens/attendance_report_screen.dart';
import '../../attendance/screens/take_attendance_screen.dart';
import '../../courses/data/courses_api.dart';
import '../../courses/screens/course_screen.dart';
import '../../setup/screens/setup_basics_screen.dart';
import '../data/home_api.dart';

/// Today at a glance. Design: Night screen 32.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> _data = HomeApi.load();

  void _reload() => setState(() { _data = HomeApi.load(); });

  /// Opens a screen, then reloads, because whatever happened there may change this one.
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AsyncBody<HomeData>(
        future: _data,
        onRetry: _reload,
        builder: (context, data) => RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _data;
          },
          child: HomeView(data: data, onOpen: _open, onChanged: _reload),
        ),
      ),
    );
  }
}

/// Separate from the loading code so it can be tested with made-up data.
class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.data, required this.onOpen, this.onChanged});

  final HomeData data;
  final ValueChanged<Widget> onOpen;
  final VoidCallback? onChanged; // something changed from the assistant, so reload

  String get _greeting {
    final hour = DateTime.now().hour;
    return hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
  }

  /// Attendance for one of today's classes, straight from Home: the teacher's most frequent job.
  Widget _attendanceFor(TodayClass item) => TakeAttendanceScreen(
        classRef: ClassRef(sectionId: item.sectionId, date: data.date, startTime: item.shortStart, title: item.courseTitle),
      );

  /// The screen for an alert: its course may be from an older semester, which Home doesn't list.
  VoidCallback? _reportFor(AttendanceAlert alert) {
    final course = data.courses.where((item) => item.id == alert.courseId).firstOrNull;
    if (course == null) return null;
    final section = Section.fromJson({'id': alert.sectionId, 'name': alert.sectionName, 'studentCount': 0});
    return () => onOpen(AttendanceReportScreen(course: course, section: section));
  }

  VoidCallback? _courseFor(ComingUp item) {
    final course = data.courses.where((one) => one.id == item.courseId).firstOrNull;
    return course == null ? null : () => onOpen(CourseScreen(course: course));
  }

  String get _initials =>
      data.teacherName.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).take(2).map((word) => word[0].toUpperCase()).join();

  @override
  Widget build(BuildContext context) {
    final next = data.nextClass;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting, style: AppText.screenTitle),
                  const SizedBox(height: 4),
                  Text(data.date, style: AppText.monoSmall.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            AssistantButton(onChanged: onChanged),
            const SizedBox(width: 4),
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
              child: Text(_initials, style: AppText.rowTitle.copyWith(color: AppColors.onGreen)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (data.offDay != null)
          HeroPanel(
            label: 'OFF DAY',
            tone: HeroTone.setup,
            child: Text(data.offDay!, style: AppText.cardTitle.copyWith(color: AppColors.onSetup)),
          )
        else if (next != null)
          HeroPanel(
            label: 'NEXT CLASS · ${next.shortStart}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  next.topics.isEmpty ? next.courseTitle : next.topics.first,
                  style: AppText.heroTitle.copyWith(color: AppColors.onGreen, fontSize: 32),
                ),
                const SizedBox(height: 10),
                Text('${next.courseCode} · Section ${next.sectionName}', style: AppText.mono.copyWith(color: AppColors.onGreenSoft)),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.onGreen, foregroundColor: AppColors.green),
                  onPressed: () => onOpen(_attendanceFor(next)),
                  child: const Text('Take attendance'),
                ),
              ],
            ),
          )
        else
          _NothingLeft(hadClasses: data.classes.isNotEmpty),
        for (final alert in data.alerts) ...[
          const SizedBox(height: 12),
          _AlertCard(alert: alert, onTap: _reportFor(alert)),
        ],
        const SizedBox(height: 24),
        if (data.classes.isNotEmpty) ...[
          Text('TODAY', style: AppText.label),
          const SizedBox(height: 10),
          for (final item in data.classes)
            _ClassRow(
              item: item,
              onTap: item.status == 'planned' || item.status == 'held' ? () => onOpen(_attendanceFor(item)) : null,
            ),
          const SizedBox(height: 14),
        ],
        // Only when an assessment happens to have a date. Otherwise this part simply isn't here.
        if (data.comingUp.isNotEmpty) ...[
          Text('COMING UP', style: AppText.label),
          const SizedBox(height: 10),
          for (final item in data.comingUp) _ComingUpRow(item: item, onTap: _courseFor(item)),
          const SizedBox(height: 14),
        ],
        Text('MY COURSES', style: AppText.label),
        const SizedBox(height: 10),
        if (data.courses.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('No courses yet.', style: AppText.body.copyWith(color: AppColors.textMuted)),
          )
        else
          for (final course in data.courses) _CourseCard(course: course, onTap: () => onOpen(CourseScreen(course: course))),
        OutlinedButton.icon(
          onPressed: () => onOpen(const SetupBasicsScreen()),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New course'),
        ),
      ],
    );
  }
}

class _NothingLeft extends StatelessWidget {
  const _NothingLeft({required this.hadClasses});

  final bool hadClasses;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: AppGlass.box(AppRadius.card),
      child: Text(hadClasses ? 'All done for today.' : 'No classes today.', style: AppText.cardTitle),
    );
  }
}

/// Students below the line in one section. Tapping shows who.
class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onTap});

  final AttendanceAlert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: HeroPanel(
        label: 'ATTENDANCE WARNING',
        tone: HeroTone.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${alert.below} ${alert.below == 1 ? 'student' : 'students'} below ${markText(alert.min)}%',
              style: AppText.cardTitle.copyWith(color: AppColors.onGreen, fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text('${alert.courseCode} · Section ${alert.sectionName}', style: AppText.rowTitle.copyWith(color: AppColors.onGreen)),
          ],
        ),
      ),
    );
  }
}

class _ComingUpRow extends StatelessWidget {
  const _ComingUpRow({required this.item, required this.onTap});

  final ComingUp item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.card,
        shape: AppGlass.shape(AppRadius.inner),
        elevation: AppGlass.lift,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.inner),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Text(shortDate(item.date), style: AppText.mono),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: AppText.rowTitle, overflow: TextOverflow.ellipsis),
                      Text(item.courseCode, style: AppText.small.copyWith(color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.item, required this.onTap});

  final TodayClass item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (item.status) {
      'held' => ('Done', PillTone.success),
      'cancelled' => ('Cancelled', PillTone.danger),
      'off_day' => ('Off day', PillTone.setup),
      _ => ('Planned', PillTone.neutral),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.card,
        shape: AppGlass.shape(AppRadius.inner),
        elevation: AppGlass.lift,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.inner),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Text(item.shortStart, style: AppText.mono),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.courseTitle, style: AppText.rowTitle, overflow: TextOverflow.ellipsis),
                      Text(
                        item.topics.isEmpty ? 'Section ${item.sectionName}' : item.topics.join(', '),
                        style: AppText.small.copyWith(color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StatusPill(label, tone: tone),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});

  final Course course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.card,
        shape: AppGlass.shape(AppRadius.card),
        elevation: AppGlass.lift,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.title, style: AppText.cardTitle),
                      const SizedBox(height: 4),
                      Text(course.code, style: AppText.monoSmall.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
