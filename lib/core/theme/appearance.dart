import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// How the app looks on this phone, saved so it survives closing the app:
/// 1. The teacher's choice on the Me screen: follow the phone, always light, or always dark.
/// 2. Each course's colour, picked once when the course is first seen.
///
/// Used by: main.dart (loads both once at start), app.dart (listens and redraws),
/// me_screen.dart (changes the choice), my_courses_screen.dart (colours new courses).
abstract final class Appearance {
  static const system = 'system';
  static const light = 'light';
  static const dark = 'dark';

  static const _key = 'appearance';
  static const _coursesKey = 'courseColours'; // saved as "courseId:index" lines

  /// A ValueNotifier is a value that tells its listeners when it changes,
  /// so app.dart can redraw the moment the teacher taps a choice.
  static final choice = ValueNotifier<String>(system);

  static Future<void> load() async {
    final storage = await SharedPreferences.getInstance();
    final saved = storage.getString(_key);
    if (saved == light || saved == dark) choice.value = saved!;
    for (final line in storage.getStringList(_coursesKey) ?? const <String>[]) {
      final (id, index) = (line.substring(0, line.lastIndexOf(':')), int.tryParse(line.substring(line.lastIndexOf(':') + 1)));
      if (index != null) AppColors.courseColourIndex[id] = index;
    }
  }

  /// Gives every course in [courseIds] that has no colour yet the colour the
  /// fewest of these courses use, so courses side by side look different.
  static Future<void> giveCourseColours(List<String> courseIds) async {
    final fresh = courseIds.where((id) => !AppColors.courseColourIndex.containsKey(id)).toList();
    if (fresh.isEmpty) return;
    for (final id in fresh) {
      final used = List.filled(AppColors.courseColours.length, 0);
      for (final other in courseIds) {
        final index = AppColors.courseColourIndex[other];
        if (index != null) used[index % used.length]++;
      }
      AppColors.courseColourIndex[id] = used.indexOf(used.reduce((a, b) => a < b ? a : b));
    }
    final lines = [for (final entry in AppColors.courseColourIndex.entries) '${entry.key}:${entry.value}'];
    await (await SharedPreferences.getInstance()).setStringList(_coursesKey, lines);
  }

  static Future<void> set(String value) async {
    choice.value = value;
    await (await SharedPreferences.getInstance()).setString(_key, value);
  }

  /// Should the app be light right now?
  static bool isLight(Brightness phone) => choice.value == light || (choice.value == system && phone == Brightness.light);
}
