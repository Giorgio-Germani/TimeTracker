import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetracker_mobile/core/theme/app_tokens.dart';
import 'package:timetracker_mobile/data/models/time_entry.dart';
import 'package:timetracker_mobile/presentation/providers/recent_work_provider.dart';
import 'package:timetracker_mobile/presentation/providers/timer_provider.dart';
import 'package:timetracker_mobile/presentation/providers/time_entries_provider.dart';

bool _sameEntries(List<TimeEntry>? a, List<TimeEntry> b) {
  if (a == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id || a[i].updatedAt != b[i].updatedAt) return false;
  }
  return true;
}

/// "Continue working on…" horizontal quick-start cards.
/// One tap starts the exact recent project/task combination — no picker.
class RecentQuickStart extends ConsumerStatefulWidget {
  const RecentQuickStart({super.key});

  @override
  ConsumerState<RecentQuickStart> createState() => _RecentQuickStartState();
}

class _RecentQuickStartState extends ConsumerState<RecentQuickStart> {
  bool _retriedEmpty = false;

  Future<void> _start(BuildContext context, WidgetRef ref, RecentWork item,
      {String? notes}) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(timerProvider.notifier).startTimer(
          projectId: item.projectId,
          clientId: item.clientId,
          taskId: item.taskId,
          notes: notes,
        );
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

    // Restartable combinations changed elsewhere (timer stopped, entry
    // created/edited) → refetch so the strip reflects them.
    ref.listen<TimeEntriesState>(timeEntriesProvider, (prev, next) {
      if (!_sameEntries(prev?.entries, next.entries)) {
        ref.read(recentWorkProvider.notifier).refresh();
      }
    });
    ref.listen<TimerState>(timerProvider, (prev, next) {
      final wasRunning = prev?.isRunning ?? false;
      if (wasRunning && !next.isRunning) {
        ref.read(recentWorkProvider.notifier).refresh();
      }
    });
    // Self-heal: a transient failure right after launch (e.g. connectivity
    // check still resolving) would otherwise hide the strip until restart.
    if (state.items.isEmpty && !state.isLoading && !_retriedEmpty) {
      _retriedEmpty = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(recentWorkProvider.notifier).refresh();
      });
    }
    if (state.items.isNotEmpty) _retriedEmpty = false;

    if (state.isLoading && state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Loading recent…', style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text('No recent items found (retry pending)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Continue working on', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: state.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = state.items[index];
              final busy = timerState.isRunning || timerState.isLoading;
              return Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: busy ? null : () => _start(context, ref, item),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          Icons.play_circle_fill,
                          size: 36,
                          color: busy
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                              if (item.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
