import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/hero_panel.dart';
import '../../../shared/widgets/prompts.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../attendance/widgets/extra_class_dialog.dart';
import '../../courses/data/courses_api.dart';
import '../data/plan_api.dart';

enum _Choice { shorten, drop, extra }

/// Not enough classes left for the outline. The app works out what each fix
/// would change, so the teacher only picks one. Design: Night screen 34.
class FixPlanScreen extends StatefulWidget {
  const FixPlanScreen({super.key, required this.course, required this.section});

  final Course course;
  final Section section;

  @override
  State<FixPlanScreen> createState() => _FixPlanScreenState();
}

class _FixPlanScreenState extends State<FixPlanScreen> {
  late Future<SectionPlan> _data = CoursesApi.plan(widget.section.id);
  _Choice? _choice;
  bool _busy = false;
  String? _error;

  void _reload() => setState(() { _data = CoursesApi.plan(widget.section.id); });

  /// The option to start on: the gentlest one that can close the gap.
  _Choice _default(List<TopicCut> cuts, List<PlanTopic> drops) {
    if (cuts.isNotEmpty) return _Choice.shorten;
    return drops.isNotEmpty ? _Choice.drop : _Choice.extra;
  }

  Future<void> _apply(_Choice choice, List<TopicCut> cuts, List<PlanTopic> drops) async {
    if (choice == _Choice.extra) {
      final added = await showDialog<bool>(context: context, builder: (_) => ExtraClassDialog(sectionId: widget.section.id));
      if (added == true) _reload();
      return;
    }
    if (choice == _Choice.drop) {
      final agreed = await confirmAction(
        context,
        title: 'Delete ${drops.length} ${drops.length == 1 ? 'topic' : 'topics'}?',
        message: '${drops.map((topic) => topic.title).join(', ')}. You can add them back later, but this removes them from every section.',
        action: 'Delete',
      );
      if (!agreed) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (choice == _Choice.shorten) {
        await Future.wait([for (final cut in cuts) PlanApi.updateTopic(cut.topic.id, classesNeeded: cut.newClasses)]);
      } else {
        await Future.wait([for (final topic in drops) PlanApi.removeTopic(topic.id)]);
      }
      if (mounted) Navigator.of(context).pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Not enough classes')),
      body: SafeArea(
        child: AsyncBody<SectionPlan>(
          future: _data,
          onRetry: _reload,
          builder: (context, plan) {
            if (plan.classesShort == 0) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: HeroPanel(label: 'ON TRACK', child: Text('The classes are enough now.', style: AppText.cardTitle.copyWith(color: AppColors.onGreen))),
              );
            }
            final cuts = PlanApi.shortenSuggestion(plan);
            final drops = PlanApi.dropSuggestion(plan);
            final choice = _choice ?? _default(cuts, drops);
            final saved = cuts.fold(0, (sum, cut) => sum + cut.topic.classesNeeded - cut.newClasses);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    children: [
                      HeroPanel(
                        label: 'SHORTFALL',
                        tone: HeroTone.danger,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${plan.classesShort} ${plan.classesShort == 1 ? 'class' : 'classes'} short', style: AppText.heroTitle.copyWith(color: AppColors.onGreen, fontSize: 32)),
                            const SizedBox(height: 8),
                            Text('${plan.classesNeeded} NEEDED · ${plan.classesAvailable} LEFT', style: AppText.mono.copyWith(color: AppColors.onGreen)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('Pick one. Classes already held are never touched.', style: AppText.body.copyWith(color: AppColors.textMuted)),
                      const SizedBox(height: 12),
                      if (cuts.isNotEmpty)
                        _Option(
                          title: 'Shorten topics',
                          detail: saved < plan.classesShort ? 'Saves $saved of the ${plan.classesShort} classes.' : 'Fewer classes on the last topics.',
                          selected: choice == _Choice.shorten,
                          onTap: () => setState(() => _choice = _Choice.shorten),
                          pills: [for (final cut in cuts) '${cut.topic.title} ${cut.topic.classesNeeded}→${cut.newClasses}'],
                        ),
                      if (drops.isNotEmpty)
                        _Option(
                          title: 'Drop topics',
                          detail: 'The last topics you haven\'t started.',
                          selected: choice == _Choice.drop,
                          onTap: () => setState(() => _choice = _Choice.drop),
                          pills: [for (final topic in drops) topic.title],
                        ),
                      _Option(
                        title: 'Add a make-up class',
                        detail: 'One extra class, on any day. The plan updates each time.',
                        selected: choice == _Choice.extra,
                        onTap: () => setState(() => _choice = _Choice.extra),
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
                        onPressed: _busy ? null : () => _apply(choice, cuts, drops),
                        child: Text(switch (choice) {
                          _ when _busy => 'Saving…',
                          _Choice.shorten => 'Shorten ${cuts.length} ${cuts.length == 1 ? 'topic' : 'topics'}',
                          _Choice.drop => 'Drop ${drops.length} ${drops.length == 1 ? 'topic' : 'topics'}',
                          _Choice.extra => 'Add a class',
                        }),
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

class _Option extends StatelessWidget {
  const _Option({required this.title, required this.detail, required this.selected, required this.onTap, this.pills = const []});

  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;
  final List<String> pills;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.inner),
            side: BorderSide(color: selected ? AppColors.green : Colors.transparent, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.inner),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? AppColors.green : AppColors.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.cardTitle.copyWith(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(detail, style: AppText.small.copyWith(color: AppColors.textMuted)),
                        if (pills.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [for (final pill in pills) StatusPill(pill, tone: PillTone.warning)]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
