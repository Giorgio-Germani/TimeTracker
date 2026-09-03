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
  final String when;

  const RecentWork({
    this.projectId,
    this.clientId,
    this.taskId,
    required this.title,
    required this.when,
    this.subtitle,
  });

  String get key => '${projectId ?? clientId ?? 0}-${taskId ?? 0}';
}

class RecentWorkState {
  final List<RecentWork> items;
  final bool isLoading;

  /// True when the last fetch failed (e.g. not authenticated yet) so the UI
  /// can distinguish "no data" from "data unavailable".
  final bool failed;

  /// Key of the combination that should carry the "JUST NOW" badge — set
  /// when a refresh was triggered by stopping the timer.
  final String? freshKey;

  const RecentWorkState({
    this.items = const [],
    this.isLoading = false,
    this.failed = false,
    this.freshKey,
  });

  RecentWorkState copyWith({
    List<RecentWork>? items,
    bool? isLoading,
    bool? failed,
    String? freshKey,
    bool clearFreshKey = false,
  }) {
    return RecentWorkState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      failed: failed ?? this.failed,
      freshKey: clearFreshKey ? null : (freshKey ?? this.freshKey),
    );
  }
}

/// Derives the last distinct project/task combinations from recent time
/// entries (any date) so the dashboard can offer one-tap restarts.
class RecentWorkNotifier extends StateNotifier<RecentWorkState> {
  final TimeTrackingRepository? repository;

  RecentWorkNotifier(this.repository) : super(const RecentWorkState()) {
    debugPrint('[RecentWork] created, repository=${repository != null}');
    // The repository becomes available asynchronously after login/config;
    // the provider is rebuilt when it does, so load right away (same
    // pattern as TimeEntriesNotifier).
    if (repository != null) {
      refresh();
    }
  }

  String _relativeTime(DateTime start) {
    final diff = DateTime.now().difference(start);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && start.day == DateTime.now().day) {
      return 'today';
    }
    if (diff.inDays < 2) return 'yesterday';
    return '${diff.inDays}d ago';
  }

  String _duration(int? seconds) {
    final s = seconds ?? 0;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '$h h ${m.toString().padLeft(2, '0')}m';
    return '$m m';
  }

  Future<void> refresh({bool markFresh = false}) async {
    if (repository == null) {
      state = state.copyWith(failed: true, isLoading: false);
      return;
    }
    state = state.copyWith(isLoading: true, failed: false);
    try {
      // Most recent entries first; no date filter so switching back to
      // yesterday's / last week's project still shows up.
      final entries = await repository!.getTimeEntries(page: 1, perPage: 20);
      debugPrint('[RecentWork] fetched ${entries.length} entries');
      final items = <RecentWork>[];
      final seen = <String>{};
      for (final e in entries) {
        if (e.projectId == null && e.clientId == null) continue;
        final key = '${e.projectId ?? e.clientId ?? 0}-${e.taskId ?? 0}';
        if (!seen.add(key)) continue;
        final task = (e.task != null && e.task!.trim().isNotEmpty)
            ? e.task!.trim()
            : ((e.notes != null && e.notes!.trim().isNotEmpty)
                ? e.notes!.trim()
                : null);
        items.add(RecentWork(
          projectId: e.projectId,
          clientId: e.clientId,
          taskId: e.taskId,
          title: e.displayLabel,
          subtitle: task,
          when:
              '${_duration(e.durationSeconds)} · ${_relativeTime(e.startTime ?? DateTime.now())}',
        ));
        if (items.length >= 6) break;
      }
      debugPrint(
          '[RecentWork] ${items.length} combinations: ${items.map((i) => i.title).join(", ")}');
      state = state.copyWith(
        items: items,
        isLoading: false,
        failed: false,
        freshKey: markFresh && items.isNotEmpty ? items.first.key : null,
        clearFreshKey: !markFresh,
      );
    } catch (e) {
      debugPrint('[RecentWork] refresh failed: $e');
      state = state.copyWith(isLoading: false, failed: true);
    }
  }
}

final recentWorkProvider =
    StateNotifierProvider<RecentWorkNotifier, RecentWorkState>((ref) {
  final repository = ref.watch(timeTrackingRepositoryProvider);
  return RecentWorkNotifier(repository);
});
