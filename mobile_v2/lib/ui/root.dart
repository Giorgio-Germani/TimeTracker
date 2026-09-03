import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../state/providers.dart';
import 'screens/timer_screen.dart';
import 'screens/history_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/settings_screen.dart';

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});
  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _tab = 0;

  static const _screens = [
    TimerScreen(),
    HistoryScreen(),
    ReportsScreen(),
    ProjectsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Validate the stored session once at startup.
    Future(() async {
      final api = ref.read(apiProvider);
      if (api == null) return;
      try {
        await api.validate();
      } catch (_) {
        await api.logout();
        if (mounted) ref.read(apiProvider.notifier).state = null;
      }
      return;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFF9F9F9),
        indicatorColor: Colors.transparent,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.access_time_outlined, size: 24, color: T.secondary),
            selectedIcon: Icon(Icons.access_time, size: 24, color: T.blue),
            label: 'Timer',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined, size: 24, color: T.secondary),
            selectedIcon: Icon(Icons.calendar_today, size: 24, color: T.blue),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined, size: 24, color: T.secondary),
            selectedIcon: Icon(Icons.bar_chart, size: 24, color: T.blue),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined, size: 24, color: T.secondary),
            selectedIcon: Icon(Icons.folder, size: 24, color: T.blue),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, size: 24, color: T.secondary),
            selectedIcon: Icon(Icons.settings, size: 24, color: T.blue),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
