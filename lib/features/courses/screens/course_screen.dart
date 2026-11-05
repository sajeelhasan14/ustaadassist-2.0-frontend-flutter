import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/hero_panel.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../assistant/screens/assistant_sheet.dart';
import '../../attendance/screens/classes_screen.dart';
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
        title: Text(_course.code),
        actions: [
          const AssistantButton(),
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
        _PlanHero(plan: plan, onAddTopics: onAddTopics),
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
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.inner)),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.onSetup, foregroundColor: AppColors.text),
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
      borderRadius: BorderRadius.circular(AppRadius.inner),
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

class _PlanHero extends StatelessWidget {
  const _PlanHero({required this.plan, required this.onAddTopics});

  final SectionPlan plan;
  final VoidCallback onAddTopics;

  @override
  Widget build(BuildContext context) {
    if (plan.topics.isEmpty) {
      return HeroPanel(
        label: 'NO PLAN YET',
        tone: HeroTone.setup,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add topics to build your plan.', style: AppText.cardTitle.copyWith(color: AppColors.onSetup)),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.onSetup, foregroundColor: AppColors.text),
              onPressed: onAddTopics,
              child: const Text('Add topics'),
            ),
          ],
        ),
      );
    }
    if (plan.classesShort > 0) {
      return HeroPanel(
        label: 'BEHIND PLAN',
        tone: HeroTone.warning,
        child: Text(
          '${plan.classesShort} ${plan.classesShort == 1 ? 'class' : 'classes'} short',
          style: AppText.heroTitle.copyWith(color: AppColors.onGreen, fontSize: 32),
        ),
      );
    }
    return HeroPanel(
      label: 'ON TRACK',
      child: Text(
        '${plan.classesAvailable} ${plan.classesAvailable == 1 ? 'class' : 'classes'} left',
        style: AppText.heroTitle.copyWith(color: AppColors.onGreen, fontSize: 32),
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
