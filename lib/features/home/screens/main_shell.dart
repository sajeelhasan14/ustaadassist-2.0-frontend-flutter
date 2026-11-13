import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../profile/screens/me_screen.dart';
import 'my_courses_screen.dart';

/// The logged-in frame: the floating dock and the screen each tab shows.
/// The first tab lists the teacher's courses; everything about a course lives inside it,
/// so two tabs are enough. (The design's sparkle button for the assistant lives inside
/// each course instead, because the assistant only ever works on one course.)
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The screens scroll behind the floating dock. Flutter then adds the dock's
      // height to the screen's bottom safe area, so nothing ends up hidden under it.
      extendBody: true,
      // IndexedStack keeps each tab alive, so switching back doesn't reload it.
      body: IndexedStack(index: _tab, children: const [MyCoursesScreen(), MeScreen()]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Center(
            heightFactor: 1,
            child: _Dock(
              tab: _tab,
              onTab: (tab) => setState(() => _tab = tab),
              tabs: const [(Icons.school_rounded, 'Courses'), (Icons.person_rounded, 'Me')],
            ),
          ),
        ),
      ),
    );
  }
}

/// A frosted pill floating above the screen. The open tab is a green pill with
/// its name; the others are just their icon.
class _Dock extends StatelessWidget {
  const _Dock({required this.tab, required this.onTab, required this.tabs});

  final int tab;
  final ValueChanged<int> onTab;
  final List<(IconData, String)> tabs;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      // BackdropFilter blurs whatever is behind the dock: the "frosted" in frosted glass.
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.dock,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, (icon, label)) in tabs.indexed) ...[
                if (index > 0) const SizedBox(width: 4),
                _DockTab(icon: icon, label: label, open: index == tab, onTap: () => onTab(index)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({required this.icon, required this.label, required this.open, required this.onTap});

  final IconData icon;
  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: open,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          // AnimatedContainer slides between the small and the wide shape when the tab changes.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: open ? 18 : 14),
            decoration: BoxDecoration(color: open ? AppColors.green : Colors.transparent, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: open ? AppColors.onGreen : AppColors.textMuted),
                if (open) ...[
                  const SizedBox(width: 8),
                  ExcludeSemantics(child: Text(label, style: AppText.button.copyWith(color: AppColors.onGreen))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
