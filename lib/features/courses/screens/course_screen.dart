import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/celebrate.dart';
import '../../../shared/widgets/hero_panel.dart';
import '../../../shared/widgets/progress_shapes.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../assistant/screens/assistant_sheet.dart';
import '../../attendance/data/attendance_api.dart';
import '../../attendance/screens/classes_screen.dart';
import '../../attendance/screens/take_attendance_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../marks/screens/assessments_screen.dart';
import '../../materials/screens/materials_screen.dart';
import '../../plan/screens/plan_screen.dart';
import '../../results/screens/results_screen.dart';
import '../../setup/data/setup_api.dart';
import '../../setup/screens/setup_topics_screen.dart';
import '../../students/screens/students_screen.dart';
import '../data/courses_api.dart';
import 'course_settings_screen.dart';

/// One course: where its plan stands, and the way into everything else about it.
/// Attendance, marks and the rest all hang off this screen, for the section chosen here.
/// Design: Night screen 33.
class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key, required this.course});

  final Course course;

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  String? _sectionId;
  late Course _course = widget.course;
  late Future<CourseOverview> _data = CoursesApi.overview(widget.course.id);

  void _reload() => setState(() { _data = CoursesApi.overview(widget.course.id, sectionId: _sectionId); });

  /// Opens a screen, then reloads, because whatever happened there may change this one.
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  Future<void> _settings(Section section) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CourseSettingsScreen(
          course: _course,
          section: section,
          onCourseChanged: (course) => setState(() => _course = course),
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'deleted') {
      Navigator.of(context).pop();
    } else {
      _reload();
    }
  }

  Future<void> _addTopics(CourseOverview data) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SetupTopicsScreen(
          standalone: true,
          // Adding topics never needs the semester, so it's left empty here.
          progress: SetupProgress(course: _course, sectionId: data.section.id, semesterId: ''),
        ),
      ),
    );
    if (added == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The course's own colour (design move 3), so it's recognisable without reading.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.courseColour(_course.id).fill, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(_course.code),
          ],
        ),
        actions: [
          FutureBuilder<CourseOverview>(
            future: _data,
            builder: (context, snapshot) => AssistantButton(courseId: _course.id, sectionId: snapshot.data?.section.id, onChanged: _reload),
          ),
          FutureBuilder<CourseOverview>(
            future: _data,
            builder: (context, snapshot) => IconButton(
              tooltip: 'Course settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: snapshot.hasData ? () => _settings(snapshot.data!.section) : null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AsyncBody<CourseOverview>(
          future: _data,
          onRetry: _reload,
          builder: (context, data) => CourseView(
            course: _course,
            data: data,
            onSection: (id) {
              _sectionId = id;
              _reload();
            },
            onAddTopics: () => _addTopics(data),
            onOpen: _open,
          ),
        ),
      ),
    );
  }
}

/// Separate from the loading code so it can be tested with made-up data.
class CourseView extends StatelessWidget {
  const CourseView({super.key, required this.course, required this.data, required this.onSection, required this.onAddTopics, required this.onOpen});

  final Course course;
  final CourseOverview data;
  final ValueChanged<String> onSection;
  final VoidCallback onAddTopics;
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    final plan = data.plan;
    final section = data.section;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(course.title, style: AppText.screenTitle),
        const SizedBox(height: 14),
        if (data.sections.length > 1) ...[
          Wrap(
            spacing: 8,
            children: [
              for (final section in data.sections)
                ChoiceChip(
                  label: Text('Section ${section.name}'),
                  selected: section.id == data.section.id,
                  onSelected: (_) => onSection(section.id),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (plan.topics.isEmpty)
          _PlanHero(onAddTopics: onAddTopics)
        else
          _Bento(course: course, section: section, plan: plan, onOpen: onOpen),
        const SizedBox(height: 12),
        if (section.studentCount == 0) ...[
          _AddStudentsNudge(onTap: () => onOpen(StudentsScreen(section: section))),
          const SizedBox(height: 12),
        ],
        _ToolGrid(
          tools: [
            ('Attendance', Icons.fact_check_outlined, ClassesScreen(course: course, section: section)),
            ('Students', Icons.groups_outlined, StudentsScreen(section: section)),
            ('Marks', Icons.edit_note_rounded, AssessmentsScreen(course: course, section: section)),
            ('Question papers', Icons.quiz_outlined, AssessmentsScreen(course: course, section: section, action: AssessmentAction.paper)),
            ('Results', Icons.workspace_premium_outlined, ResultsScreen(course: course, section: section)),
            ('Materials', Icons.folder_open_rounded, MaterialsScreen(course: course)),
            ('Plan', Icons.event_note_rounded, PlanScreen(course: course, section: section)),
            ('Dashboard', Icons.insights_rounded, DashboardScreen(course: course, section: section)),
          ],
          onOpen: onOpen,
        ),
        const SizedBox(height: 22),
        if (plan.topics.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: Text('TOPICS', style: AppText.label)),
              Text('${plan.topicsDone} / ${plan.topics.length}', style: AppText.monoSmall.copyWith(color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: AppGlass.box(AppRadius.inner),
            child: Column(
              children: [
                for (final (index, topic) in plan.topics.indexed) ...[
                  if (index > 0) const Divider(),
                  _TopicRow(topic: topic),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AddStudentsNudge extends StatelessWidget {
  const _AddStudentsNudge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      decoration: BoxDecoration(color: AppColors.setup, borderRadius: BorderRadius.circular(AppRadius.inner)),
      child: Row(
        children: [
          Expanded(child: Text('No students yet. Photograph the class list.', style: AppText.rowTitle.copyWith(color: AppColors.onSetup))),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.onSetup, foregroundColor: AppColors.setup),
            onPressed: onTap,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

/// The way into each part of the course, two to a row.
class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.tools, required this.onOpen});

  final List<(String, IconData, Widget)> tools;
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < tools.length; index += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: _Tool(tool: tools[index], onOpen: onOpen)),
                const SizedBox(width: 8),
                Expanded(child: index + 1 < tools.length ? _Tool(tool: tools[index + 1], onOpen: onOpen) : const SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.tool, required this.onOpen});

  final (String, IconData, Widget) tool;
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    final (label, icon, screen) = tool;
    return Material(
      color: AppColors.card,
      shape: AppGlass.shape(AppRadius.inner),
      elevation: AppGlass.lift,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.inner),
        onTap: () => onOpen(screen),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textMuted),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: AppText.rowTitle)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A course with no topics yet: one job to do, so one violet panel.
class _PlanHero extends StatelessWidget {
  const _PlanHero({required this.onAddTopics});

  final VoidCallback onAddTopics;

  @override
  Widget build(BuildContext context) {
    return HeroPanel(
      label: 'NO PLAN YET',
      tone: HeroTone.setup,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add topics to build your plan.', style: AppText.cardTitle.copyWith(color: AppColors.onSetup)),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.onSetup, foregroundColor: AppColors.setup),
            onPressed: onAddTopics,
            child: const Text('Add topics'),
          ),
        ],
      ),
    );
  }
}

/// The course at a glance as tiles of different sizes (design move 2, "bento"):
/// a wide status tile with the next class, two number tiles, and the syllabus
/// as one block per topic. Everything comes from the plan this screen already
/// loaded, so it costs no extra request.
class _Bento extends StatelessWidget {
  const _Bento({required this.course, required this.section, required this.plan, required this.onOpen});

  final Course course;
  final Section section;
  final SectionPlan plan;
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    // Average attendance: everyone present in marked classes / everyone counted.
    final held = [for (final item in plan.sessions) if (item.status == 'held' && item.present + item.absent > 0) item];
    final present = held.fold(0, (sum, item) => sum + item.present);
    final counted = held.fold(0, (sum, item) => sum + item.present + item.absent);
    final average = counted == 0 ? null : present * 100 / counted;
    final lastSeven = held.length > 7 ? held.sublist(held.length - 7) : held;
    final topics = plan.topics.length;
    final behind = plan.classesShort > 0;
    final barColour = AppColors.courseColour(course.id).text; // charts use the course's colour (move 3)

    return Column(
      children: [
        _StatusTile(course: course, section: section, plan: plan, onOpen: onOpen),
        const SizedBox(height: 8),
        // IntrinsicHeight makes the two tiles in this row the same height.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppGlass.box(AppRadius.inner),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      average == null
                          ? Text('–', style: AppText.bigNumber.copyWith(fontSize: 36))
                          : CountUp(average, style: AppText.bigNumber.copyWith(fontSize: 36), suffix: '%', suffixStyle: AppText.rowTitle),
                      Text(average == null ? 'no class marked yet' : 'average attendance', style: AppText.small.copyWith(color: AppColors.textMuted)),
                      const Spacer(),
                      const SizedBox(height: 8),
                      // One bar per recent class: how full that class was.
                      SizedBox(
                        height: 24,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final item in lastSeven) ...[
                              Container(
                                width: 8,
                                height: 4 + 20 * item.present / (item.present + item.absent),
                                decoration: BoxDecoration(color: barColour, borderRadius: BorderRadius.circular(2)),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppGlass.box(AppRadius.inner),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProgressRing(
                        value: topics == 0 ? 0 : plan.topicsDone / topics,
                        size: 64,
                        child: Text('${plan.topicsDone}', style: AppText.cardTitle),
                      ),
                      const SizedBox(height: 8),
                      Text('of $topics topics taught', style: AppText.small.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppGlass.box(AppRadius.inner),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Syllabus', style: AppText.rowTitle)),
                  Text(
                    '${plan.topicsDone} / $topics${behind ? ' · ${plan.classesShort} behind' : ''}',
                    style: AppText.monoSmall.copyWith(color: behind ? AppColors.warningText : AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // One block per topic: green taught, violet in progress, grey still to come.
              SegmentBar(
                colours: [
                  for (final topic in plan.topics)
                    switch (topic.status) {
                      'done' => AppColors.greenText,
                      'in_progress' => AppColors.warning,
                      _ => AppColors.line,
                    },
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The wide tile: on track (green) or behind (violet), the giant "classes left"
/// number, a thin syllabus bar, and the next class with a go button.
/// When every topic is taught, the "ALL DONE!" stamp appears (design move 7).
class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.course, required this.section, required this.plan, required this.onOpen});

  final Course course;
  final Section section;
  final SectionPlan plan;
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    final behind = plan.classesShort > 0;
    final allDone = plan.topics.every((topic) => topic.status == 'done');
    final fill = behind ? AppColors.warning : AppColors.green;
    final ink = behind ? AppColors.onSetup : AppColors.onGreen; // dark text on both fills
    final next = plan.sessions.where((item) => item.status == 'planned' && item.date.compareTo(plan.today) >= 0).firstOrNull;
    final nextTopic = next?.topics.firstOrNull ?? plan.nextTopic;
    final isToday = next != null && next.date == plan.today;
    final words = behind
        ? '${plan.classesShort} ${plan.classesShort == 1 ? 'class' : 'classes'} short'
        : '${plan.classesAvailable} ${plan.classesAvailable == 1 ? 'class' : 'classes'} left';

    // Today's class: straight into attendance. A later one: the list of classes.
    void go() => onOpen(isToday && section.studentCount > 0
        ? TakeAttendanceScreen(classRef: ClassRef(sectionId: section.id, date: next.date, startTime: next.startTime, title: course.title))
        : ClassesScreen(course: course, section: section));

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: next == null ? null : go,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: ink, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(behind ? 'BEHIND PLAN' : 'ON TRACK', style: AppText.label.copyWith(color: ink))),
                  if (allDone) DoneStamp('ALL DONE!', colour: ink),
                ],
              ),
              const SizedBox(height: 10),
              // The headline number (design move 1): giant, so it's read first.
              Text(words, style: AppText.heroTitle.copyWith(color: ink, fontSize: 34, height: 1)),
              const SizedBox(height: 12),
              // How far through the syllabus, as a thin bar in the tile's own ink.
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                  value: plan.topics.isEmpty ? 0 : plan.topicsDone / plan.topics.length,
                  minHeight: 5,
                  color: ink,
                  backgroundColor: ink.withValues(alpha: 0.16),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      next == null
                          ? 'No class planned ahead'
                          : 'Next · ${isToday ? 'Today' : shortDate(next.date)} ${next.startTime}${nextTopic == null ? '' : ' · ${nextTopic.title}'}',
                      style: AppText.rowTitle.copyWith(color: ink, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (next != null) ...[
                    const SizedBox(width: 10),
                    Tooltip(
                      message: isToday ? 'Take attendance' : 'See classes',
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
                        child: Icon(Icons.arrow_forward_rounded, color: fill, size: 20),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});

  final PlanTopic topic;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (topic.status) {
      'done' => ('Done', PillTone.success),
      'in_progress' => ('In progress', PillTone.warning),
      _ => ('Planned', PillTone.neutral),
    };
    final firstDate = topic.plannedDates.firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.title, style: AppText.rowTitle),
                const SizedBox(height: 2),
                Text(
                  '${topic.classesNeeded} ${topic.classesNeeded == 1 ? 'class' : 'classes'}${firstDate == null ? '' : ' · from ${shortDate(firstDate)}'}',
                  style: AppText.small.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusPill(label, tone: tone),
        ],
      ),
    );
  }
}
