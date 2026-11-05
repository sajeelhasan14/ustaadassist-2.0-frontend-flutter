import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/card_list.dart';
import '../../../shared/widgets/empty_note.dart';
import '../../../shared/widgets/hero_panel.dart';
import '../../courses/data/courses_api.dart';
import '../data/attendance_api.dart';

/// Taking attendance for one class. Everyone starts present, so the teacher
/// only taps the few who aren't. Design: Night screen 36.
class TakeAttendanceScreen extends StatefulWidget {
  const TakeAttendanceScreen({super.key, required this.classRef});

  final ClassRef classRef;

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  late Future<AttendanceSheet> _data = _load();
  final Set<String> _absent = {};
  List<TopicRef> _topics = [];
  bool _busy = false;
  String? _error;

  Future<AttendanceSheet> _load() async {
    final sheet = await AttendanceApi.open(widget.classRef);
    _absent
      ..clear()
      ..addAll(sheet.students.where((student) => !student.present).map((student) => student.id));
    _topics = sheet.topics;
    return sheet;
  }

  Future<void> _save(AttendanceSheet sheet) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AttendanceApi.save(sheet.sessionId, absent: _absent.toList(), topicIds: [for (final topic in _topics) topic.id]);
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

  Future<void> _changeTopics(AttendanceSheet sheet) async {
    final chosen = await showModalBottomSheet<List<TopicRef>>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      builder: (_) => _TopicPicker(outline: sheet.outline, selected: _topics),
    );
    if (chosen != null) setState(() => _topics = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final ref = widget.classRef;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ref.title, overflow: TextOverflow.ellipsis),
            Text('${weekdayName(ref.date)} ${shortDate(ref.date)} · ${ref.startTime}', style: AppText.monoSmall.copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
      body: SafeArea(
        child: AsyncBody<AttendanceSheet>(
          future: _data,
          onRetry: () => setState(() { _data = _load(); }),
          builder: (context, sheet) {
            if (sheet.students.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: EmptyNote(title: 'No students yet', message: 'Add the class list from the course\'s Students screen first.'),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    children: [
                      _Counts(present: sheet.students.length - _absent.length, absent: _absent.length),
                      const SizedBox(height: 12),
                      _TaughtRow(topics: _topics, onTap: sheet.outline.isEmpty ? null : () => _changeTopics(sheet)),
                      const SizedBox(height: 18),
                      Text('${sheet.students.length} STUDENTS', style: AppText.label),
                      const SizedBox(height: 10),
                      CardList(
                        children: [
                          for (final student in sheet.students)
                            _StudentRow(
                              student: student,
                              absent: _absent.contains(student.id),
                              onTap: () => setState(() => _absent.contains(student.id) ? _absent.remove(student.id) : _absent.add(student.id)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Text(_error!, style: AppText.small.copyWith(color: AppColors.dangerText)),
                        const SizedBox(height: 10),
                      ],
                      FilledButton(
                        onPressed: _busy ? null : () => _save(sheet),
                        child: Text(_busy ? 'Saving…' : (sheet.marked ? 'Update attendance' : 'Submit attendance')),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.present, required this.absent});

  final int present;
  final int absent;

  @override
  Widget build(BuildContext context) {
    return HeroPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$present', style: AppText.bigNumber.copyWith(color: AppColors.onGreen)),
                  const SizedBox(width: 6),
                  Text('present', style: AppText.small.copyWith(color: AppColors.onGreenSoft, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              Text('$absent absent', style: AppText.rowTitle.copyWith(color: AppColors.onGreenSoft)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Everyone starts present. Tap only those who are not.',
              textAlign: TextAlign.right,
              style: AppText.small.copyWith(color: AppColors.onGreenSoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// What was taught sits here because it shares this screen's save, not because it depends on attendance.
class _TaughtRow extends StatelessWidget {
  const _TaughtRow({required this.topics, required this.onTap});

  final List<TopicRef> topics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.inner),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.inner),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TAUGHT TODAY', style: AppText.label),
                    const SizedBox(height: 4),
                    Text(topics.isEmpty ? 'No topic chosen' : topics.map((topic) => topic.title).join(', '), style: AppText.rowTitle),
                  ],
                ),
              ),
              if (onTap != null) Text('Change', style: AppText.small.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, required this.absent, required this.onTap});

  final RosterStudent student;
  final bool absent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${student.fullName}, ${absent ? 'absent' : 'present'}',
      excludeSemantics: true,
      child: Material(
        color: absent ? AppColors.dangerTint : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.fullName, style: AppText.rowTitle),
                      const SizedBox(height: 2),
                      Text(student.rollNumber, style: AppText.monoSmall.copyWith(color: absent ? AppColors.dangerText : AppColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: absent ? AppColors.danger : AppColors.successTint, borderRadius: BorderRadius.circular(10)),
                  child: Icon(absent ? Icons.close_rounded : Icons.check_rounded, size: 20, color: absent ? AppColors.onDanger : AppColors.successText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicPicker extends StatefulWidget {
  const _TopicPicker({required this.outline, required this.selected});

  final List<PlanTopic> outline;
  final List<TopicRef> selected;

  @override
  State<_TopicPicker> createState() => _TopicPickerState();
}

class _TopicPickerState extends State<_TopicPicker> {
  late final Map<String, TopicRef> _chosen = {for (final topic in widget.selected) topic.id: topic};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('What did you teach?', style: AppText.cardTitle),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final topic in widget.outline)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _chosen.containsKey(topic.id),
                        activeColor: AppColors.green,
                        checkColor: AppColors.onGreen,
                        title: Text(topic.title, style: AppText.rowTitle),
                        onChanged: (ticked) => setState(() {
                          if (ticked == true) {
                            _chosen[topic.id] = TopicRef.fromJson({'id': topic.id, 'title': topic.title});
                          } else {
                            _chosen.remove(topic.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(onPressed: () => Navigator.of(context).pop(_chosen.values.toList()), child: const Text('Done')),
            ],
          ),
        ),
      ),
    );
  }
}
