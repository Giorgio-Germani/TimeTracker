import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timetracker_mobile/domain/repositories/time_tracking_repository.dart';
import 'package:timetracker_mobile/presentation/providers/timer_provider.dart';

/// One restartable project/task combination derived from recent time entries.
class RecentWork {
  final int? projectId;
  final int? clientId;
  final int? taskId;
  final String title;
  final String? subtitle;

  const RecentWork({
    this.projectId,
    this.clientId,
    this.taskId,
    required this.title,
    this.subtitle,
  });

  String get key => '${projectId ?? clientId ?? 0}-${taskId ?? 0}';
}

class RecentWorkState {
  final List<RecentWork> items;
  final bool isLoading;

  const RecentWorkState({this.items = const [], this.isLoading = false});

  RecentWorkState copyWith({List<RecentWork>? items, bool? isLoading}) {
    return RecentWorkState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Derives the last distinct project/task combinations from recent time
/// entries (any date) so the dashboard can offer one-tap restarts.
class RecentWorkNotifier extends StateNotifier<RecentWorkState> {
  final TimeTrackingRepository? repository;

  RecentWorkNotifier(this.repository) : super(const RecentWorkState()) {
    print('[RecentWork] created, repository=${repository != null}');
    // The repository becomes available asynchronously after login/config;
    // the provider is rebuilt when it does, so load right away (same
    // pattern as TimeEntriesNotifier).
    if (repository != null) {
      refresh();
    }
  }

  Future<void> refresh() async {
    if (repository == null) return;
    state = state.copyWith(isLoading: true);
    try {
      // Most recent entries first; no date filter so switching back to
      // yesterday's / last week's project still shows up.
      final entries = await repository!.getTimeEntries(page: 1, perPage: 20);
      print('[RecentWork] fetched ${entries.length} entries');
      final items = <RecentWork>[];
      final seen = <String>{};
      for (final e in entries) {
        if (e.projectId == null && e.clientId == null) continue;
        final key = '${e.projectId ?? e.clientId ?? 0}-${e.taskId ?? 0}';
        if (!seen.add(key)) continue;
        items.add(RecentWork(
          projectId: e.projectId,
          clientId: e.clientId,
          taskId: e.taskId,
          title: e.displayLabel,
          subtitle: (e.task != null && e.task!.trim().isNotEmpty)
              ? e.task!.trim()
              : ((e.notes != null && e.notes!.trim().isNotEmpty)
                  ? e.notes!.trim()
                  : null),
        ));
        if (items.length >= 5) break;
      }
      state = state.copyWith(items: items, isLoading: false);
      print('[RecentWork] ${items.length} combinations: ${items.map((i) => i.title).join(", ")}');
    } catch (e) {
      print('[RecentWork] refresh failed: $e');
      state = state.copyWith(isLoading: false);
    }
  }
}

final recentWorkProvider =
    StateNotifierProvider<RecentWorkNotifier, RecentWorkState>((ref) {
  final repository = ref.watch(timeTrackingRepositoryProvider);
  return RecentWorkNotifier(repository);
});
