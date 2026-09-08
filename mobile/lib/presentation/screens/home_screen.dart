import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetracker_mobile/data/models/project.dart';
import 'package:timetracker_mobile/data/models/time_entry.dart';
import 'package:timetracker_mobile/core/theme/app_tokens.dart';
import '../providers/attendance_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/time_entries_provider.dart';
import '../providers/projects_provider.dart';
import '../providers/recent_work_provider.dart';
import '../providers/user_prefs_provider.dart';
import 'package:timetracker_mobile/utils/date_format_utils.dart';
import 'package:timetracker_mobile/core/services/idle_detection_service.dart';
import 'package:timetracker_mobile/core/services/notification_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/recent_quick_start.dart';
import '../widgets/workday_card.dart';
import 'timer_screen.dart';
import 'projects_screen.dart';
import 'time_entries_screen.dart';
import 'settings_screen.dart';
import 'finance_workforce_screen.dart';
import 'more_hub_screen.dart';
import 'dart:async';
import 'dart:ui';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  bool _showingIdleDialog = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.onIdlePromptOpened = _showIdlePromptDialog;
    // The app may have been cold-started by tapping the idle notification.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (NotificationService.instance.consumePendingPromptOpened()) {
        _showIdlePromptDialog();
      }
    });
  }

  @override
  void dispose() {
    NotificationService.instance.onIdlePromptOpened = null;
    super.dispose();
  }

  void _showIdlePromptDialog() {
    final idle = IdleDetectionService.instance;
    if (!mounted || _showingIdleDialog || !idle.isRunning) return;
    setState(() => _showingIdleDialog = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final promptActive = idle.isPromptActive;
        return AlertDialog(
          title: Text(promptActive ? 'Still working?' : 'Timer needs review'),
          content: Text(
            promptActive
                ? 'You have been idle. Keep the timer running?'
                : 'You were idle and did not answer. The timer kept running — trim the idle time or stop it in the timer screen.',
          ),
          actions: [
            if (promptActive)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _showingIdleDialog = false;
                  idle.respondToIdlePrompt(IdlePromptAction.stop);
                },
                child: const Text('No, stop timer'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showingIdleDialog = false;
                if (promptActive) {
                  idle.respondToIdlePrompt(IdlePromptAction.stillWorking);
                }
              },
              child: Text(promptActive ? 'Yes, still working' : 'OK'),
            ),
          ],
        );
      },
    ).then((_) => _showingIdleDialog = false);
  }

  final List<Widget> _screens = [
    const DashboardTab(),
    const ProjectsScreen(),
    const TimeEntriesScreen(),
    const FinanceWorkforceScreen(),
    const MoreHubScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Entries',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Finance',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? GestureDetector(
              // Long-press instantly restarts the most recent project/task
              // combination; tap opens the full start flow.
              onLongPress: () async {
                final recents = ref.read(recentWorkProvider).items;
                if (recents.isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(timerProvider.notifier).startTimer(
                      projectId: recents.first.projectId,
                      clientId: recents.first.clientId,
                      taskId: recents.first.taskId,
                    );
                final err = ref.read(timerProvider).error;
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(err != null
                        ? err
                        : 'Started: ${recents.first.title}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TimerScreen(),
                    ),
                  );
                },
                tooltip: 'Start timer (long-press: resume last)',
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Timer'),
              ),
            )
          : null,
    );
  }
}


class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });

    // Load data on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadAll();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadAll();
    }
  }

  void _reloadAll() {
    ref.read(timerProvider.notifier).checkTimerStatus();
    ref.read(attendanceProvider.notifier).refresh();
    ref.read(projectsProvider.notifier).loadProjects();
    ref.read(recentWorkProvider.notifier).refresh();
    _loadWeekEntries();
  }

  void _loadWeekEntries() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final from = DateTime(monday.year, monday.month, monday.day);
    ref.read(timeEntriesProvider.notifier).loadTimeEntries(
          startDate:
              '${from.year.toString().padLeft(4, '0')}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}',
          endDate:
              '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        );
  }

  String _formatTimer(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String _entryLabel(TimeEntry entry, List<Project> projects) {
    if (entry.projectId != null) {
      try {
        return projects.firstWhere((p) => p.id == entry.projectId).name;
      } catch (_) {
        /* fall through */
      }
    }
    return entry.displayLabel == 'Time entry' ? 'Unknown project' : entry.displayLabel;
  }

  String _formatHours(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '$h h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerProvider);
    final entriesState = ref.watch(timeEntriesProvider);
    final attendanceState = ref.watch(attendanceProvider);
    final projectsState = ref.watch(projectsProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();

    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    var todayTotal = 0;
    final weekSeconds = List<int>.filled(7, 0);
    var weekBillable = 0;
    var weekTotal = 0;
    for (final e in entriesState.entries) {
      final start = e.startTime;
      if (start == null) continue;
      // Weekday index: Monday = 0.
      final weekdayIdx = start.weekday - 1;
      if (weekdayIdx < 0 || weekdayIdx > 6) continue;
      final sec = e.durationSeconds ?? 0;
      weekSeconds[weekdayIdx] += sec;
      weekTotal += sec;
      if (e.billable) weekBillable += sec;
      final dayKey =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      if (dayKey == todayKey) todayTotal += sec;
    }
    final runningElapsed = timerState.isActive
        ? ref.read(timerProvider.notifier).getElapsedTime().inSeconds
        : 0;

    final billablePct = weekTotal > 0 ? (weekBillable * 100 / weekTotal).round() : 0;
    final maxDaySeconds = weekSeconds.fold<int>(1, (a, b) => a > b ? a : b);

    // Workday chip from attendance "today" record (defensive about keys).
    String? workdayLabel;
    final attendanceToday = attendanceState.today;
    if (attendanceToday != null) {
      final raw =
          attendanceToday['total_hours'] ?? attendanceToday['worked_hours'] ?? attendanceToday['hours'];
      final hours = raw is num ? raw.toDouble() : double.tryParse('$raw');
      if (hours != null) {
        final h = hours.floor();
        final m = ((hours - h) * 60).round();
        workdayLabel = 'At work ${h}h ${m.toString().padLeft(2, '0')}m';
      }
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _reloadAll(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // ---- Slim top row (replaces the AppBar headline) ----
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _weekdayName(now.weekday),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Week ${_isoWeekNumber(now)} · ${now.day} ${_monthName(now.month)} ${now.year}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (workdayLabel != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle,
                              size: 7,
                              color: attendanceState.workActive
                                  ? Colors.green
                                  : theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 5),
                          Text(
                            workdayLabel,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    ),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // ---- Start hero (idle) / running pill ----
              if (timerState.isActive && timerState.activeTimer != null)
                _RunningPill(
                  elapsed: _formatTimer(Duration(seconds: runningElapsed)),
                  projectName: timerState.activeTimer!.project ?? 'Timer',
                  taskName: timerState.activeTimer!.notes ?? '',
                  isPaused: timerState.isPaused,
                  onPauseResume: () {
                    if (timerState.isPaused) {
                      ref.read(timerProvider.notifier).resumeTimer();
                    } else {
                      ref.read(timerProvider.notifier).pauseTimer();
                    }
                  },
                  onStop: () => ref.read(timerProvider.notifier).stopTimer(),
                )
              else
                _StartHero(
                  onStart: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TimerScreen()),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),

              // ---- Resume / Switch-to strip (always visible) ----
              const RecentQuickStart(),
              const SizedBox(height: AppSpacing.md),

              // ---- Dense stats strip ----
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    _StatCell(
                        value: _formatHours(todayTotal + runningElapsed),
                        label: timerState.isActive ? 'Today (live)' : 'Today'),
                    _divider(theme),
                    _StatCell(
                        value: _formatHours(weekTotal + runningElapsed),
                        label: timerState.isActive ? 'Week (live)' : 'Week'),
                    _divider(theme),
                    _StatCell(value: '$billablePct%', label: 'Billable'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ---- Week bars ----
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('This week',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text('target 40 h',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 84,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < 7; i++)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final barHeight = weekSeconds[i] == 0
                                        ? 3.0
                                        : (weekSeconds[i] /
                                                (maxDaySeconds * 1.15)) *
                                            56.0;
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          height: barHeight.clamp(3.0, 56.0),
                                          decoration: BoxDecoration(
                                            color: i == now.weekday - 1
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.primary
                                                    .withValues(alpha: 0.25),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(6)),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _weekdayName(i + 1)
                                              .substring(0, 2)
                                              .toLowerCase(),
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            fontSize: 9,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ---- Recent entries (compact, below the fold) ----
              Row(
                children: [
                  Text('Recent entries',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      )),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const TimeEntriesScreen()),
                    ),
                    child: const Text('View all'),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5)),
                ),
                child: entriesState.isLoading && entriesState.entries.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))),
                      )
                    : entriesState.entries.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              'No entries this week yet',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          )
                        : Column(
                            children: [
                              for (final entry
                                  in entriesState.entries.take(4))
                                _EntryRow(
                                  entry: entry,
                                  label: _entryLabel(
                                      entry, projectsState.projects),
                                ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(ThemeData theme) => Container(
        width: 1,
        height: 34,
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
      );

  String _weekdayName(int weekday) {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return names[(weekday - 1) % 7];
  }

  String _monthName(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[(month - 1) % 12];
  }

  int _isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final yearStart = DateTime(thursday.year, 1, 1);
    return ((thursday.difference(yearStart).inDays) / 7).ceil() + 1;
  }
}

class _StartHero extends StatelessWidget {
  final VoidCallback onStart;

  const _StartHero({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.play_arrow, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start timer',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text('Pick project & task',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Text(
                'long-press FAB\n= resume last',
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunningPill extends StatelessWidget {
  final String elapsed;
  final String projectName;
  final String taskName;
  final bool isPaused;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;

  const _RunningPill({
    required this.elapsed,
    required this.projectName,
    required this.taskName,
    required this.isPaused,
    required this.onPauseResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runningColor = isPaused
        ? theme.colorScheme.secondaryContainer
        : Colors.green.shade900;
    final runningInk =
        isPaused ? theme.colorScheme.onSecondaryContainer : Colors.green.shade50;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: runningColor,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(
            isPaused ? Icons.pause_circle : Icons.circle,
            size: 11,
            color: isPaused ? null : Colors.lightGreenAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                      color: runningInk, fontWeight: FontWeight.w700),
                ),
                if (taskName.isNotEmpty)
                  Text(
                    taskName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: runningInk.withValues(alpha: 0.8)),
                  ),
              ],
            ),
          ),
          Text(
            elapsed,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: runningInk,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          _pillButton(
            context,
            icon: isPaused ? Icons.play_arrow : Icons.pause,
            onTap: onPauseResume,
          ),
          const SizedBox(width: 6),
          _pillButton(
            context,
            icon: Icons.stop,
            color: theme.colorScheme.error,
            onTap: onStop,
          ),
        ],
      ),
    );
  }

  Widget _pillButton(BuildContext context,
      {required IconData icon, required VoidCallback onTap, Color? color}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 40,
      height: 40,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor:
              color ?? theme.colorScheme.onSurface.withValues(alpha: 0.12),
          foregroundColor: color == null
              ? Theme.of(context).colorScheme.onSurface
              : theme.colorScheme.onError,
        ),
        onPressed: onTap,
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;

  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends ConsumerWidget {
  final TimeEntry entry;
  final String label;

  const _EntryRow({required this.entry, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final taskName =
        (entry.task != null && entry.task!.trim().isNotEmpty)
            ? entry.task!.trim()
            : null;
    final dateKey = ref.watch(userPrefsProvider).valueOrNull?.dateFormatKey;
    final subtitle = taskName != null
        ? '$taskName · ${formatDateRange(entry.startTime, entry.endTime, dateKey)}'
        : formatDateRange(entry.startTime, entry.endTime, dateKey);

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(Icons.circle, size: 9, color: theme.colorScheme.primary),
      title: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(entry.formattedDuration,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Resume',
            icon: const Icon(Icons.replay),
            onPressed: () async {
              await ref.read(timerProvider.notifier).startTimer(
                    projectId: entry.projectId,
                    clientId: entry.clientId,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Started: $label'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
