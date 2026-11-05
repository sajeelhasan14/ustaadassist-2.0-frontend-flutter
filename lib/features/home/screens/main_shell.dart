import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../profile/screens/me_screen.dart';
import 'home_screen.dart';

/// The logged-in frame: the bottom tabs and the screen each one shows.
/// Everything about a course lives on its course screen, so two tabs are enough.
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
      // IndexedStack keeps each tab alive, so switching back doesn't reload it.
      body: IndexedStack(index: _tab, children: const [HomeScreen(), MeScreen()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (tab) => setState(() => _tab = tab),
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.line,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: AppColors.green), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: AppColors.green), label: 'Me'),
        ],
      ),
    );
  }
}
