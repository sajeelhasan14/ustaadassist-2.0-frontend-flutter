import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/card_list.dart';
import '../../../shared/widgets/prompts.dart';
import '../../setup/data/setup_api.dart';
import '../../setup/screens/setup_holidays_screen.dart';
import '../../setup/widgets/timetable_editor.dart';
import '../data/courses_api.dart';

/// Everything about a course that rarely changes after setup.
/// Pops 'deleted' if the course is gone, so the course screen can close too.
class CourseSettingsScreen extends StatefulWidget {
  const CourseSettingsScreen({super.key, required this.course, required this.section, required this.onCourseChanged});

  final Course course;
  final Section section; // whose timetable is shown
  final ValueChanged<Course> onCourseChanged;

  @override
  State<CourseSettingsScreen> createState() => _CourseSettingsScreenState();
}

class _CourseSettingsScreenState extends State<CourseSettingsScreen> {
  late final _title = TextEditingController(text: widget.course.title);
  late final _code = TextEditingController(text: widget.course.code);
  late Future<(List<Section>, List<ClassSlot>)> _data = _load();
  List<ClassSlot> _slots = [];
  bool _savingTimetable = false;

  Future<(List<Section>, List<ClassSlot>)> _load() async {
    final loaded = await (CoursesApi.sections(widget.course.id), SetupApi.timetable(widget.section.id)).wait;
    _slots = loaded.$2;
    return loaded;
  }

  @override
  void dispose() {
    _title.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _change(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() { _data = _load(); });
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  Future<void> _saveDetails() async {
    try {
      final course = await CoursesApi.update(widget.course.id, title: _title.text.trim(), code: _code.text.trim());
      widget.onCourseChanged(course);
      if (mounted) showMessage(context, 'Saved.');
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  Future<void> _addSection() async {
    final name = await askText(context, title: 'Add a section', label: 'Name, e.g. B');
    if (name != null) await _change(() => CoursesApi.addSection(widget.course.id, name));
  }

  Future<void> _renameSection(Section section) async {
    final name = await askText(context, title: 'Rename section', label: 'Name', initial: section.name);
    if (name != null) await _change(() => CoursesApi.renameSection(section.id, name));
  }

  Future<void> _removeSection(Section section) async {
    final agreed = await confirmAction(
      context,
      title: 'Delete section ${section.name}?',
      message: 'Its timetable, attendance and enrolments go with it.',
      action: 'Delete',
    );
    if (agreed) await _change(() => CoursesApi.removeSection(section.id));
  }

  Future<void> _saveTimetable() async {
    if (_slots.any((slot) => slot.endTime.compareTo(slot.startTime) <= 0)) {
      showMessage(context, 'A class must end after it starts.');
      return;
    }
    setState(() => _savingTimetable = true);
    try {
      await SetupApi.saveTimetable(widget.section.id, _slots);
      if (mounted) showMessage(context, 'Timetable saved. The plan has updated.');
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
    if (mounted) setState(() => _savingTimetable = false);
  }

  Future<void> _removeCourse() async {
    final agreed = await confirmAction(
      context,
      title: 'Delete ${widget.course.title}?',
      message: 'Every section, class, mark and paper of this course goes with it. This can\'t be undone.',
      action: 'Delete course',
    );
    if (!agreed) return;
    try {
      await CoursesApi.remove(widget.course.id);
      if (mounted) Navigator.of(context).pop('deleted');
    } catch (error) {
      if (mounted) showMessage(context, '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Course settings')),
      body: SafeArea(
        child: AsyncBody<(List<Section>, List<ClassSlot>)>(
          future: _data,
          onRetry: () => setState(() { _data = _load(); }),
          builder: (context, data) {
            final (sections, _) = data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Text('DETAILS', style: AppText.label),
                const SizedBox(height: 10),
                TextField(controller: _title, style: AppText.input, decoration: const InputDecoration(labelText: 'Course name')),
                const SizedBox(height: 10),
                TextField(controller: _code, style: AppText.mono, decoration: const InputDecoration(labelText: 'Code')),
                const SizedBox(height: 10),
                FilledButton.tonal(onPressed: _saveDetails, child: const Text('Save details')),
                const SizedBox(height: 24),
                Text('SECTIONS', style: AppText.label),
                const SizedBox(height: 10),
                CardList(
                  children: [
                    for (final section in sections)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text('Section ${section.name}', style: AppText.rowTitle)),
                            Text('${section.studentCount} students', style: AppText.small.copyWith(color: AppColors.textMuted)),
                            PopupMenuButton<void>(
                              tooltip: 'Section options',
                              color: AppColors.line,
                              icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
                              itemBuilder: (_) => [
                                PopupMenuItem(onTap: () => _renameSection(section), child: Text('Rename', style: AppText.body)),
                                // A course always keeps at least one section.
                                if (sections.length > 1)
                                  PopupMenuItem(onTap: () => _removeSection(section), child: Text('Delete', style: AppText.body.copyWith(color: AppColors.dangerText))),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _addSection, icon: const Icon(Icons.add_rounded), label: const Text('Add a section')),
                const SizedBox(height: 24),
                Text('TIMETABLE · SECTION ${widget.section.name}', style: AppText.label),
                const SizedBox(height: 10),
                TimetableEditor(slots: _slots, onChanged: () => setState(() {})),
                const SizedBox(height: 4),
                FilledButton.tonal(onPressed: _savingTimetable ? null : _saveTimetable, child: Text(_savingTimetable ? 'Saving…' : 'Save timetable')),
                if (widget.course.semesterId.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('HOLIDAYS', style: AppText.label),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SetupHolidaysScreen(
                          standalone: true,
                          progress: SetupProgress(course: widget.course, sectionId: widget.section.id, semesterId: widget.course.semesterId),
                        ),
                      ),
                    ),
                    child: const Text('Check holidays'),
                  ),
                ],
                const SizedBox(height: 32),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.dangerText),
                  onPressed: _removeCourse,
                  child: const Text('Delete this course'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
