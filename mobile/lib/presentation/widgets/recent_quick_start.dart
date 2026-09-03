import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetracker_mobile/core/theme/app_tokens.dart';
import 'package:timetracker_mobile/data/models/time_entry.dart';
import 'package:timetracker_mobile/presentation/providers/recent_work_provider.dart';
import 'package:timetracker_mobile/presentation/providers/timer_provider.dart';
import 'package:timetracker_mobile/presentation/providers/time_entries_provider.dart';

bool _sameEntries(List<TimeEntry>? a, List<TimeEntry>? b) {
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id || a[i].updatedAt != b[i].updatedAt) return false;
  }
  return true;
}

Color _projectColor(String seed, BuildContext context) {
  const palette = [
    Color(0xFF2563eb), Color(0xFF16a34a), Color(0xFFd97706),
    Color(0xFF9333ea), Color(0xFFdc2626), Color(0xFF0891b2),
    Color(0xFF65a30d), Color(0xFFdb2777),
  ];
  var hash = 0;
  for (var i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.codeUnitAt(i)) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

/// "Resume" / "Switch to" horizontal quick-start cards.
/// One tap starts the exact recent project/task combination — no picker.
/// Visible on the dashboard at all times (also while a timer runs, where a
/// tap stops the current timer and starts the tapped combination).
class RecentQuickStart extends ConsumerStatefulWidget {
  const RecentQuickStart({super.key});

  @override
  ConsumerState<RecentQuickStart> createState() => _RecentQuickStartState();
}

class _RecentQuickStartState extends ConsumerState<RecentQuickStart> {
  bool _switching = false;

  Future<void> _start(BuildContext context, WidgetRef ref, RecentWork item,
      {String? notes}) async {
    if (_switching) return;
    final messenger = ScaffoldMessenger.of(context);
    final timerNotifier = ref.read(timerProvider.notifier);

    setState(() => _switching = true);
    // Single-active-timer mode: while something runs, a tap means "switch".
    if (ref.read(timerProvider).isActive) {
      await timerNotifier.stopTimer();
    }
    await timerNotifier.startTimer(
      projectId: item.projectId,
      clientId: item.clientId,
      taskId: item.taskId,
      notes: notes,
    );
    if (mounted) setState(() => _switching = false);

    final state = ref.read(timerProvider);
    if (state.error != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(state.error!), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    // Refresh recents so the started combination moves to the front.
    unawaited(ref.read(recentWorkProvider.notifier).refresh());
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Started: ${item.title}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recentWorkProvider);
    final timerState = ref.watch(timerProvider);
    final theme = Theme.of(context);
    final running = timerState.isActive;

    // Restartable combinations changed elsewhere (timer stopped, entry
    // created/edited) → refetch so the strip reflects them immediately.
    ref.listen<TimeEntriesState>(timeEntriesProvider, (prev, next) {
      if (!_sameEntries(prev?.entries, next.entries)) {
        ref.read(recentWorkProvider.notifier).refresh();
      }
    });
    ref.listen<TimerState>(timerProvider, (prev, next) {
      final wasActive = prev?.isActive ?? false;
      if (wasActive && !next.isActive) {
        // Timer just stopped — refresh and mark the stopped combination
        // fresh so it jumps to the front with a "just now" badge.
        ref.read(recentWorkProvider.notifier).refresh(markFresh: true);
      }
    });
    // Self-heal: a transient failure right after launch (e.g. connectivity
    // check still resolving) would otherwise hide the strip until restart.
    if (state.items.isEmpty && !state.isLoading && !state.failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(recentWorkProvider.notifier).refresh();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 2, bottom: 6),
          child: Row(
            children: [
              Text(
                running ? 'Switch to' : 'Resume',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                running ? 'tap = stop & start' : 'one tap starts',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (state.isLoading && state.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (state.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              state.failed
                  ? 'Recent tasks unavailable — pull down to retry'
                  : 'No recent tasks yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: state.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = state.items[index];
                final isRunningItem = running && index == 0;
                final isFresh = !running && state.freshKey == item.key;
                final busy = _switching;
                final color = _projectColor(item.title, context);
                return _ResumeCard(
                  item: item,
                  color: color,
                  isRunningItem: isRunningItem,
                  isFresh: isFresh,
                  enabled: !busy && !isRunningItem,
                  onTap: () => _start(context, ref, item),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ResumeCard extends StatelessWidget {
  final RecentWork item;
  final Color color;
  final bool isRunningItem;
  final bool isFresh;
  final bool enabled;
  final VoidCallback onTap;

  const _ResumeCard({
    required this.item,
    required this.color,
    required this.isRunningItem,
    required this.isFresh,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = 172.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            side: BorderSide(
              color: isFresh
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: isFresh ? 1.4 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: width,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (item.subtitle != null && item.subtitle!.isNotEmpty)
                                ? item.subtitle!
                                : (isRunningItem ? 'running now' : item.subtitle ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isRunningItem
                                ? 'running now'
                                : (isFresh ? 'tap to continue' : item.when),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isFresh
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: isFresh ? FontWeight.w700 : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.play_circle_fill,
                      size: 30,
                      color: enabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isFresh)
          Positioned(
            top: -8,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'JUST NOW',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
