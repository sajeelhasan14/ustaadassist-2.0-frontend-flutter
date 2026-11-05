import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/card_list.dart';
import '../../../shared/widgets/empty_note.dart';
import '../../../shared/widgets/hero_panel.dart';
import '../../../shared/widgets/prompts.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../attendance/data/attendance_api.dart';
import '../../attendance/screens/take_attendance_screen.dart';
import '../../courses/data/courses_api.dart';
import '../../setup/data/setup_api.dart';
import '../../setup/screens/setup_topics_screen.dart';
import '../data/plan_api.dart';
import 'fix_plan_screen.dart';

/// One week of the calendar. The Monday identifies it.
class PlanWeek {
  PlanWeek(this.monday, this.sessions);

  final String monday;
  final List<ClassSession> sessions;

  /// Groups the semester's classes by the week they fall in.
  static List<PlanWeek> from(List<ClassSession> sessions) {
    final weeks = <String, List<ClassSession>>{};
    for (final session in sessions) {
      final date = DateTime.parse('${session.date}T00:00:00Z');
      final monday = isoDate(date.subtract(Duration(days: date.weekday - 1)));
      weeks.putIfAbsent(monday, () => []).add(session);
    }
    return [for (final entry in weeks.entries) PlanWeek(entry.key, entry.value)];
  }

  bool contains(String iso) {
    final start = DateTime.parse('${monday}T00:00:00Z');
    final date = DateTime.parse('${iso}T00:00:00Z');
    final days = date.difference(start).inDays;
    return days >= 0 && days < 7;
  }
}

/// Which topic goes in which class, and whether the classes are enough. Nothing
/// here needs replanning: the backend works the plan out afresh every time, so
/// a cancelled class or a moved holiday shows up on its own. Design: Night screen 33.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.course, required this.section});

  final Course course;
  final Section section;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late Future<SectionPlan> _data = CoursesApi.plan(widget.section.id);
  String? _week; // the Monday of the chosen week; null = the current one

  void _reload() => setState(() { _data = CoursesApi.plan(widget.section.id); });

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  Future<void> _change(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) _reload();
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  Future<void> _editTopic(PlanTopic topic) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _TopicDialog(topic: topic));
    if (saved == true) _reload();
  }

  Future<void> _removeTopic(PlanTopic topic) async {
    final agreed = await confirmAction(
      context,
      title: 'Delete ${topic.title}?',
      message: 'It leaves the outline of every section of this course.',
      action: 'Delete',
    );
    if (agreed) await _change(() => PlanApi.removeTopic(topic.id));
  }

  Future<void> _move(SectionPlan plan, int index, int by) async {
    final ids = [for (final topic in plan.topics) topic.id];
    final moved = ids.removeAt(index);
    ids.insert(index + by, moved);
    await _change(() => PlanApi.reorderTopics(widget.course.id, ids));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Plan · Section ${widget.section.name}')),
      body: SafeArea(
        child: AsyncBody<SectionPlan>(
          future: _data,
          onRetry: _reload,
          builder: (context, plan) {
            final weeks = PlanWeek.from(plan.sessions);
            final current = weeks.indexWhere((week) => week.contains(plan.today));
            final chosen = weeks.indexWhere((week) => week.monday == _week);
            final index = chosen >= 0 ? chosen : (current >= 0 ? current : 0);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                _Health(
                  plan: plan,
                  onFix: () => _open(FixPlanScreen(course: widget.course, section: widget.section)),
                  onAddTopics: () => _open(SetupTopicsScreen(
                    standalone: true,
                    progress: SetupProgress(course: widget.course, sectionId: widget.section.id, semesterId: ''),
                  )),
                ),
                const SizedBox(height: 16),
                if (weeks.isEmpty)
                  const EmptyNote(title: 'No classes yet', message: 'Set this section\'s timetable in course settings.')
                else ...[
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      // Starts near the chosen week, so a long semester doesn't hide it off screen.
                      controller: ScrollController(initialScrollOffset: index * 58.0),
                      itemCount: weeks.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, position) => ChoiceChip(
                        label: Text('W${position + 1}'),
                        showCheckmark: false,
                        selected: position == index,
                        onSelected: (_) => setState(() => _week = weeks[position].monday),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('WEEK ${index + 1} · FROM ${shortDate(weeks[index].monday)}', style: AppText.label),
                  const SizedBox(height: 10),
                  CardList(
                    children: [
                      for (final session in weeks[index].sessions)
                        _ClassRow(
                          session: session,
                          today: plan.today,
                          onTake: () => _open(TakeAttendanceScreen(
                            classRef: ClassRef(sectionId: widget.section.id, date: session.date, startTime: session.startTime, title: widget.course.title),
                          )),
                        ),
                    ],
                  ),
                ],
                if (plan.topics.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('OUTLINE', style: AppText.label),
                  const SizedBox(height: 10),
                  CardList(
                    children: [
                      for (final (position, topic) in plan.topics.indexed)
                        _TopicRow(
                          topic: topic,
                          onEdit: () => _editTopic(topic),
                          onRemove: () => _removeTopic(topic),
                          onUp: position == 0 ? null : () => _move(plan, position, -1),
                          onDown: position == plan.topics.length - 1 ? null : () => _move(plan, position, 1),
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Health extends StatelessWidget {
  const _Health({required this.plan, required this.onFix, required this.onAddTopics});

  final SectionPlan plan;
  final VoidCallback onFix;
  final VoidCallback onAddTopics;

  @override
  Widget build(BuildContext context) {
    final dark = FilledButton.styleFrom(backgroundColor: AppColors.onGreen, foregroundColor: AppColors.text);
    if (plan.topics.isEmpty) {
      return HeroPanel(
        label: 'NO PLAN YET',
        tone: HeroTone.setup,
        child: Row(
          children: [
            Expanded(child: Text('Add topics to build it.', style: AppText.cardTitle.copyWith(color: AppColors.onSetup))),
            FilledButton(style: dark, onPressed: onAddTopics, child: const Text('Add')),
          ],
        ),
      );
    }
    final short = plan.classesShort;
    return HeroPanel(
      label: short > 0 ? 'BEHIND PLAN' : 'ON TRACK',
      tone: short > 0 ? HeroTone.warning : HeroTone.green,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  short > 0 ? '$short ${short == 1 ? 'class' : 'classes'} short' : '${plan.classesAvailable} classes left',
                  style: AppText.heroTitle.copyWith(color: AppColors.onGreen, fontSize: 30),
                ),
                const SizedBox(height: 6),
                Text('${plan.classesHeld} held · ${plan.classesNeeded} still needed', style: AppText.small.copyWith(color: AppColors.onGreen)),
              ],
            ),
          ),
          if (short > 0) FilledButton(style: dark, onPressed: onFix, child: const Text('Fix it')),
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.session, required this.today, required this.onTake});

  final ClassSession session;
  final String today;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    final isToday = session.date == today;
    final struck = session.status == 'cancelled' || session.status == 'off_day';
    final canTake = session.status == 'planned' && session.date.compareTo(today) <= 0;
    final title = session.topics.map((topic) => topic.title).join(', ');
    final (label, tone) = switch (session.status) {
      'held' => ('Done', PillTone.success),
      'cancelled' => ('Cancelled', PillTone.danger),
      'off_day' => ('Off day', PillTone.setup),
      _ => ('Planned', PillTone.neutral),
    };
    return Container(
      color: isToday ? AppColors.line : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(weekdayName(session.date), style: AppText.mono),
                Text(isToday ? 'TODAY' : shortDate(session.date), style: AppText.monoSmall.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? (session.offDayName ?? session.startTime) : title,
                  style: AppText.rowTitle.copyWith(
                    color: struck ? AppColors.textMuted : AppColors.text,
                    decoration: session.status == 'cancelled' ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (title.isNotEmpty) Text(session.startTime, style: AppText.small.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canTake)
            GestureDetector(
              onTap: onTake,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: const ShapeDecoration(color: AppColors.green, shape: StadiumBorder()),
                child: Text('Take', style: AppText.pill.copyWith(color: AppColors.onGreen)),
              ),
            )
          else
            StatusPill(label, tone: tone),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.onEdit, required this.onRemove, required this.onUp, required this.onDown});

  final PlanTopic topic;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (topic.status) {
      'done' => ('Done', PillTone.success),
      'in_progress' => ('In progress', PillTone.warning),
      _ => ('Planned', PillTone.neutral),
    };
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.title, style: AppText.rowTitle),
                  const SizedBox(height: 2),
                  Text('${topic.classesTaught} of ${topic.classesNeeded} classes', style: AppText.small.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusPill(label, tone: tone),
            PopupMenuButton<void>(
              tooltip: 'Topic options',
              color: AppColors.line,
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
              itemBuilder: (_) => [
                if (onUp != null) PopupMenuItem(onTap: onUp, child: Text('Move up', style: AppText.body)),
                if (onDown != null) PopupMenuItem(onTap: onDown, child: Text('Move down', style: AppText.body)),
                PopupMenuItem(onTap: onRemove, child: Text('Delete', style: AppText.body.copyWith(color: AppColors.dangerText))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Renames a topic or changes how many classes it needs. Pops true once saved.
class _TopicDialog extends StatefulWidget {
  const _TopicDialog({required this.topic});

  final PlanTopic topic;

  @override
  State<_TopicDialog> createState() => _TopicDialogState();
}

class _TopicDialogState extends State<_TopicDialog> {
  late final _title = TextEditingController(text: widget.topic.title);
  late int _classes = widget.topic.classesNeeded;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a title.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PlanApi.updateTopic(widget.topic.id, title: title, classesNeeded: _classes);
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
      title: Text('Edit topic', style: AppText.cardTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: _title, style: AppText.input, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('Classes needed', style: AppText.rowTitle)),
              IconButton(
                tooltip: 'One less',
                icon: const Icon(Icons.remove_rounded),
                onPressed: _classes > 1 ? () => setState(() => _classes--) : null,
              ),
              Text('$_classes', style: AppText.mono),
              IconButton(
                tooltip: 'One more',
                icon: const Icon(Icons.add_rounded),
                onPressed: _classes < 50 ? () => setState(() => _classes++) : null,
              ),
            ],
          ),
          if (_error != null) Text(_error!, style: AppText.small.copyWith(color: AppColors.dangerText)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
