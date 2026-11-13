import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/hero_panel.dart';
import '../../attendance/screens/attendance_report_screen.dart';
import '../../attendance/screens/classes_screen.dart';
import '../../courses/data/courses_api.dart';
import '../data/dashboard_api.dart';

/// How one section is doing, at a glance. Every number comes from the backend.
/// Design: Night screen 37, with class averages per assessment in place of
/// per-topic scores, because marks aren't linked to topics.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.course, required this.section});

  final Course course;
  final Section section;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardData> _data = DashboardApi.load(widget.section.id);

  void _reload() => setState(() { _data = DashboardApi.load(widget.section.id); });

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard · Section ${widget.section.name}')),
      body: SafeArea(
        child: AsyncBody<DashboardData>(
          future: _data,
          onRetry: _reload,
          builder: (context, data) => DashboardView(
            data: data,
            onAtRisk: () => _open(AttendanceReportScreen(course: widget.course, section: widget.section)),
            onNotMarked: () => _open(ClassesScreen(course: widget.course, section: widget.section)),
          ),
        ),
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key, required this.data, required this.onAtRisk, required this.onNotMarked});

  final DashboardData data;
  final VoidCallback onAtRisk;
  final VoidCallback onNotMarked;

  @override
  Widget build(BuildContext context) {
    final plan = data.plan;
    final topics = plan.topics.length;
    final short = plan.classesShort;
    final atRisk = data.attendance.short.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        HeroPanel(
          label: 'SCHEDULE HEALTH',
          tone: short > 0 ? HeroTone.warning : HeroTone.green,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                short > 0 ? '$short ${short == 1 ? 'class' : 'classes'} behind your plan' : 'On track',
                style: AppText.heroTitle.copyWith(color: AppColors.onGreen, fontSize: 32),
              ),
              if (topics > 0) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: plan.topicsDone / topics,
                          minHeight: 8,
                          color: AppColors.onGreen,
                          backgroundColor: AppColors.onGreen.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${plan.topicsDone} / $topics', style: AppText.mono.copyWith(color: AppColors.onGreen)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Stat(label: 'SYLLABUS', value: topics == 0 ? '–' : '${plan.topicsDone}/$topics')),
            const SizedBox(width: 10),
            Expanded(child: _Stat(label: 'ATTENDANCE', value: data.attendance.average == null ? '–' : '${data.attendance.average!.round()}%')),
            const SizedBox(width: 10),
            Expanded(child: _Stat(label: 'AT RISK', value: '$atRisk', alert: atRisk > 0, onTap: onAtRisk)),
          ],
        ),
        const SizedBox(height: 12),
        _Averages(items: data.averages),
        if (plan.notMarked > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
            decoration: BoxDecoration(color: AppColors.setup, borderRadius: BorderRadius.circular(AppRadius.inner)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${plan.notMarked} past ${plan.notMarked == 1 ? 'class has' : 'classes have'} no attendance yet.',
                    style: AppText.rowTitle.copyWith(color: AppColors.onSetup),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.onSetup, foregroundColor: AppColors.setup),
                  onPressed: onNotMarked,
                  child: const Text('Mark'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One number with its label. Coral only when the number needs acting on.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.alert = false, this.onTap});

  final String label;
  final String value;
  final bool alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = alert ? AppColors.onDanger : AppColors.text;
    return Material(
      color: alert ? AppColors.danger : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.inner),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.inner),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label, style: AppText.label.copyWith(color: alert ? AppColors.onDanger : AppColors.textMuted, letterSpacing: 1)),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: AppText.cardTitle.copyWith(fontSize: 26, color: foreground)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single series, so no legend: the heading names it. The number beside each
/// bar is the real value, so the colour is never the only way to read it.
class _Averages extends StatelessWidget {
  const _Averages({required this.items});

  final List<AssessmentAverage> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppGlass.box(AppRadius.inner),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CLASS AVERAGE PER ASSESSMENT', style: AppText.label),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text('Appears once you add assessments.', style: AppText.small.copyWith(color: AppColors.textMuted))
          else
            for (final item in items) _AverageRow(item: item),
        ],
      ),
    );
  }
}

class _AverageRow extends StatelessWidget {
  const _AverageRow({required this.item});

  final AssessmentAverage item;

  @override
  Widget build(BuildContext context) {
    final average = item.average;
    final low = average != null && average < 50; // the university's pass line
    return Semantics(
      label: '${item.name}: ${average == null ? 'no marks yet' : '$average percent'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(flex: 4, child: Text(item.name, style: AppText.rowTitle, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (average ?? 0) / 100,
                  minHeight: 8,
                  color: low ? AppColors.danger : AppColors.success,
                  backgroundColor: AppColors.line,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              child: Text(average == null ? '–' : '${average.round()}%', textAlign: TextAlign.right, style: AppText.mono),
            ),
          ],
        ),
      ),
    );
  }
}
