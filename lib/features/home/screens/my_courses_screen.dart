import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_body.dart';
import '../../courses/data/courses_api.dart';
import '../../courses/screens/course_screen.dart';
import '../../setup/screens/setup_basics_screen.dart';

/// What the first screen needs: who is signed in, and every one of their courses.
class MyCoursesData {
  MyCoursesData({required this.teacherName, required this.courses});

  final String teacherName;
  final List<Course> courses;
}

/// The first screen after signing in: the teacher's courses by name. Tap one to go inside it.
/// Each course is separate, so nothing here mixes data from two courses.
class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  late Future<MyCoursesData> _data = _load();

  /// The two requests don't depend on each other, so they run together.
  static Future<MyCoursesData> _load() async {
    final (me, list) = await (api.get('/me'), api.get('/courses')).wait;
    return MyCoursesData(
      teacherName: me['teacher']['fullName'] as String,
      courses: [for (final item in list['courses'] as List) Course.fromJson(item as Map<String, dynamic>)],
    );
  }

  void _reload() => setState(() { _data = _load(); });

  /// Opens a screen, then reloads, because a course may have been added, renamed or deleted there.
  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AsyncBody<MyCoursesData>(
        future: _data,
        onRetry: _reload,
        builder: (context, data) => RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _data;
          },
          child: MyCoursesView(data: data, onOpen: _open),
        ),
      ),
    );
  }
}

/// Kept apart from the loading code so tests can show it with made-up data.
class MyCoursesView extends StatelessWidget {
  const MyCoursesView({super.key, required this.data, required this.onOpen});

  final MyCoursesData data;
  final ValueChanged<Widget> onOpen;

  String get _greeting {
    final hour = DateTime.now().hour;
    return hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
  }

  String get _firstName => data.teacherName.trim().split(RegExp(r'\s+')).first;

  String get _initials =>
      data.teacherName.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).take(2).map((word) => word[0].toUpperCase()).join();

  @override
  Widget build(BuildContext context) {
    final empty = data.courses.isEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      children: [
        Row(
          children: [
            Expanded(child: Text('$_greeting, $_firstName', style: AppText.body.copyWith(color: AppColors.textMuted))),
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
              child: Text(_initials, style: AppText.rowTitle.copyWith(color: AppColors.onGreen)),
            ),
          ],
        ),
        const SizedBox(height: 22),
        // "Your courses." in two lines, the second in green, like the chosen design.
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Your\n'),
            TextSpan(text: 'courses.', style: TextStyle(color: AppColors.green)),
          ]),
          style: AppText.heroTitle.copyWith(fontSize: 46, height: 0.98),
        ),
        const SizedBox(height: 24),
        if (empty)
          _FirstCourse(onTap: () => onOpen(const SetupBasicsScreen()))
        else ...[
          for (final course in data.courses) _CourseCard(course: course, onTap: () => onOpen(CourseScreen(course: course))),
          _NewCourseCard(onTap: () => onOpen(const SetupBasicsScreen())),
        ],
      ],
    );
  }
}

/// One course: just its name, big, with an arrow. Tapping opens the course.
class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});

  final Course course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 20, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: Text(course.title, style: AppText.heroTitle.copyWith(fontSize: 28, height: 1.05))),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: AppColors.text, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_rounded, color: AppColors.ground, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Below the courses: start another one. Same three setup steps every time.
class _NewCourseCard extends StatelessWidget {
  const _NewCourseCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: const BorderSide(color: AppColors.outline, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text('New course', style: AppText.button.copyWith(color: AppColors.textMuted, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A brand-new teacher has no courses yet: say so, and offer the one thing to do next.
class _FirstCourse extends StatelessWidget {
  const _FirstCourse({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No courses yet.', style: AppText.cardTitle.copyWith(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            'Add the course name and class days, paste your topics, and your semester plan is ready.',
            style: AppText.body.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onTap, child: const Text('Create your first course')),
          ),
        ],
      ),
    );
  }
}
