import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';
import '../data/models.dart';

/// Currently authenticated API handle (null = signed out).
final apiProvider = StateProvider<Api?>((ref) => null);

/// Live timer status; refreshed on a ticker so elapsed time keeps moving.
final timerProvider =
    AsyncNotifierProvider<TimerController, TimerStatus>(TimerController.new);

class TimerController extends AsyncNotifier<TimerStatus> {
  Timer? _tick;
  Map<String, dynamic> _context = {}; // projectId/taskId of running timer

  @override
  Future<TimerStatus> build() async {
    ref.onDispose(() => _tick?.cancel());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = state.value;
      if (s != null && s.running) state = AsyncData(s); // re-evaluates elapsed
    });
    final api = ref.read(apiProvider);
    if (api == null) return TimerStatus();
    try {
      final m = await api.getMap('/api/v1/timer/status');
      final s = TimerStatus.fromMap(m);
      if (s.running) {
        _context = {
          'project_id': s.projectId,
          'task_id': s.taskId,
        };
        // Best effort: fill names for the hero card.
        await _loadNames();
      }
      return s;
    } catch (_) {
      return TimerStatus();
    }
  }

  Future<void> _loadNames() async {
    final api = ref.read(apiProvider);
    if (api == null) return;
    try {
      final pid = _context['project_id'];
      final tid = _context['task_id'];
      if (tid != null) {
        final tasks = await api.getList('/api/v1/tasks');
        final t = tasks.where((x) => x['id'] == tid).toList();
        if (t.isNotEmpty) _context['task_name'] = t.first['name'];
      }
      if (pid != null) {
        final projects = await api.getList('/api/v1/projects');
        final p = projects.where((x) => x['id'] == pid).toList();
        if (p.isNotEmpty) _context['project_name'] = p.first['name'];
      }
    } catch (_) {/* names are cosmetic */}
  }

  String get currentProjectName => (_context['project_name'] ?? '') as String;
  String get currentTaskName => (_context['task_name'] ?? '') as String;
  int? get currentProjectId => _context['project_id'] as int?;
  int? get currentTaskId => _context['task_id'] as int?;

  Future<void> start({int? projectId, int? taskId}) async {
    final api = ref.read(apiProvider);
    if (api == null) return;
    state = const AsyncLoading();
    try {
      await api.post('/api/v1/timer/start', {
        if (projectId != null) 'project_id': projectId,
        if (taskId != null) 'task_id': taskId,
      });
      _context = {'project_id': projectId, 'task_id': taskId};
      await _loadNames();
      state = AsyncData(TimerStatus(
          running: true, start: DateTime.now(), projectId: projectId, taskId: taskId));
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      ref.invalidateSelf();
    }
  }

  Future<void> stop() async {
    final api = ref.read(apiProvider);
    if (api == null) return;
    try {
      await api.post('/api/v1/timer/stop', {});
    } catch (_) {}
    _context = {};
    state = AsyncData(TimerStatus());
    ref.read(entriesReloadProvider.notifier).update((v) => v + 1);
  }
}

/// Bumping this re-fetches day lists / recents after mutations.
final entriesReloadProvider = StateProvider<int>((ref) => 0);

/// All entries for [day].
final entriesForDayProvider =
    FutureProvider.family<List<TimeEntry>, DateTime>((ref, day) async {
  ref.watch(entriesReloadProvider);
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  final from = DateTime(day.year, day.month, day.day).toUtc().toIso8601String();
  final to = DateTime(day.year, day.month, day.day + 1).toUtc().toIso8601String();
  try {
    final list = await api.getList('/api/v1/time-entries',
        query: {'start_date': from, 'end_date': to});
    final entries = list.map(TimeEntry.fromMap).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return entries;
  } catch (_) {
    return [];
  }
});

/// Entries across the last [days] days — drives recents + reports.
final recentEntriesProvider =
    FutureProvider.family<List<TimeEntry>, int>((ref, days) async {
  ref.watch(entriesReloadProvider);
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  final now = DateTime.now();
  final from =
      DateTime(now.year, now.month, now.day - days).toUtc().toIso8601String();
  try {
    final list = await api.getList('/api/v1/time-entries',
        query: {'start_date': from});
    return list.map(TimeEntry.fromMap).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
  } catch (_) {
    return [];
  }
});

/// Distinct recent project/task combos, newest first.
final recentsProvider = Provider<List<TimeEntry>>((ref) {
  final all = ref.watch(recentEntriesProvider(14)).value ?? [];
  final seen = <String>{};
  final out = <TimeEntry>[];
  for (final e in all) {
    final key = '${e.projectId}|${e.taskId}';
    if (seen.add(key)) out.add(e);
    if (out.length >= 5) break;
  }
  return out;
});

final projectsProvider = FutureProvider<List<Project>>((ref) async {
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  try {
    final list = await api.getList('/api/v1/projects');
    final projects = list.map(Project.fromMap).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return projects;
  } catch (_) {
    return [];
  }
});

final tasksForProjectProvider =
    FutureProvider.family<List<Task>, int>((ref, projectId) async {
  final api = ref.watch(apiProvider);
  if (api == null) return [];
  try {
    final list = await api.getList('/api/v1/tasks',
        query: {'project_id': projectId});
    return list.map(Task.fromMap).where((t) => t.projectId == projectId).toList();
  } catch (_) {
    return [];
  }
});

/// Week report (Mon..Sun of the week containing [refDay]).
final weekReportProvider =
    FutureProvider.family<ReportSummary, DateTime>((ref, refDay) async {
  ref.watch(entriesReloadProvider);
  final api = ref.watch(apiProvider);
  if (api == null) return ReportSummary();
  final base = DateTime(refDay.year, refDay.month, refDay.day);
  final monday = base.subtract(Duration(days: base.weekday - 1));
  final from = monday.toUtc().toIso8601String();
  final to = DateTime(monday.year, monday.month, monday.day + 7).toUtc().toIso8601String();
  try {
    final list = await api.getList('/api/v1/time-entries',
        query: {'start_date': from, 'end_date': to});
    return ReportSummary.fromMap({}, list);
  } catch (_) {
    return ReportSummary();
  }
});

/// Simple local preferences.
class Prefs {
  Prefs(this._p);
  final SharedPreferences _p;
  bool get idleDetection => _p.getBool('idle_detection') ?? true;
  int get idleTimeoutMin => _p.getInt('idle_timeout') ?? 30;
  bool get defaultBillable => _p.getBool('default_billable') ?? false;
  Future<void> set(String key, dynamic v) async {
    if (v is bool) await _p.setBool(key, v);
    if (v is int) await _p.setInt(key, v);
  }
}

final prefsProvider = FutureProvider<Prefs>((ref) async {
  final p = await SharedPreferences.getInstance();
  return Prefs(p);
});

/// Dismissed idle-review windows (kept for the session).
class IdleCase {
  IdleCase({required this.window, required this.entryContext});
  final Duration window;
  final String entryContext;
}
