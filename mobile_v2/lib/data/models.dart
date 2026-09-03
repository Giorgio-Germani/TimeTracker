/// Tolerant models — the backend uses snake_case in places, camelCase in
/// others; every model accepts both and never throws on unknown shapes.

class Project {
  Project({
    required this.id,
    required this.name,
    this.clientName,
    this.color,
    this.status,
    this.billable = false,
    this.lastUsedAt,
  });

  final int id;
  final String name;
  final String? clientName;
  final String? color;
  final String? status;
  final bool billable;
  final DateTime? lastUsedAt;

  bool get isArchived =>
      status != null && status!.toLowerCase() != 'active';

  factory Project.fromMap(Map<String, dynamic> m) {
    String? client;
    for (final k in const ['client_name', 'clientName', 'client']) {
      final v = m[k];
      if (v is String && v.isNotEmpty) { client = v; break; }
      if (v is Map && (v['name'] ?? '') is String) {
        client = v['name'] as String?;
        if (client?.isNotEmpty ?? false) break;
      }
    }
    return Project(
      id: _toInt(m['id']),
      name: (m['name'] ?? 'Untitled') as String,
      clientName: client,
      color: (m['color'] ?? m['colour']) as String?,
      status: m['status'] as String?,
      billable: m['billable'] == true || m['billable'] == 1,
      lastUsedAt: _toDate(m['last_used_at'] ?? m['lastUsedAt']),
    );
  }

  static const _palette = [
    '0A84FF', '5E5CE6', 'FF9F0A', '30D158', 'FF453A', '64D2FF', 'BF5AF2',
  ];
  String get hexColor {
    final c = (color ?? '').replaceAll('#', '');
    if (c.length == 6 || c.length == 8) return c;
    return _palette[id.abs() % _palette.length];
  }
}

class Task {
  Task({required this.id, required this.name, required this.projectId, this.status});
  final int id;
  final String name;
  final int projectId;
  final String? status;

  factory Task.fromMap(Map<String, dynamic> m) => Task(
        id: _toInt(m['id']),
        name: (m['name'] ?? 'Untitled task') as String,
        projectId: _toInt(m['project_id'] ?? m['projectId']),
        status: m['status'] as String?,
      );
}

class TimeEntry {
  TimeEntry({
    required this.id,
    this.projectId,
    this.taskId,
    required this.start,
    this.end,
    this.notes,
    this.tags = const [],
    this.billable = false,
    this.projectName,
    this.taskName,
    this.clientName,
  });

  final int id;
  final int? projectId;
  final int? taskId;
  final DateTime start;
  final DateTime? end;
  final String? notes;
  final List<String> tags;
  final bool billable;
  final String? projectName;
  final String? taskName;
  final String? clientName;

  bool get running => end == null;
  Duration get duration =>
      running ? DateTime.now().difference(start) : end!.difference(start);

  String get displayName => taskName ?? projectName ?? 'Untitled';

  factory TimeEntry.fromMap(Map<String, dynamic> m) {
    List<String> tagList = [];
    final t = m['tags'];
    if (t is List) {
      tagList = t.map((e) => e.toString()).toList();
    } else if (t is String && t.trim().isNotEmpty) {
      tagList = t.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return TimeEntry(
      id: _toInt(m['id']),
      projectId: _toNullableInt(m['project_id'] ?? m['projectId']),
      taskId: _toNullableInt(m['task_id'] ?? m['taskId']),
      start: _toDate(m['start'] ?? m['start_time'] ?? m['startTime']) ?? DateTime.now(),
      end: _toDate(m['end'] ?? m['end_time'] ?? m['endTime']),
      notes: m['notes'] as String?,
      tags: tagList,
      billable: m['billable'] == true || m['billable'] == 1,
      projectName: (m['project_name'] ?? m['projectName'] ?? m['project']) as String?,
      taskName: (m['task_name'] ?? m['taskName'] ?? m['task']) as String?,
      clientName: (m['client_name'] ?? m['clientName']) as String?,
    );
  }

  Map<String, dynamic> toApi({required bool isRunning}) => {
        if (projectId != null) 'project_id': projectId,
        if (taskId != null) 'task_id': taskId,
        'start': start.toIso8601String(),
        if (!isRunning && end != null) 'end': end!.toIso8601String(),
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (tags.isNotEmpty) 'tags': tags.join(','),
        'billable': billable,
      };
}

class TimerStatus {
  TimerStatus({this.running = false, this.start, this.projectId, this.taskId});
  final bool running;
  final DateTime? start;
  final int? projectId;
  final int? taskId;

  Duration get elapsed =>
      running && start != null ? DateTime.now().difference(start!) : Duration.zero;

  factory TimerStatus.fromMap(Map<String, dynamic> m) {
    final running = m['running'] == true ||
        m['active'] == true ||
        m['is_running'] == true ||
        (m['status'] is String && (m['status'] as String).toLowerCase() == 'running') ||
        (m['start_time'] ?? m['startTime'] ?? m['started_at']) != null;
    return TimerStatus(
      running: running,
      start: _toDate(m['start_time'] ?? m['startTime'] ?? m['started_at'] ?? m['start']),
      projectId: _toNullableInt(m['project_id'] ?? m['projectId']),
      taskId: _toNullableInt(m['task_id'] ?? m['taskId']),
    );
  }
}

class ReportSummary {
  ReportSummary({this.totalSeconds = 0, this.billableSeconds = 0, this.byProject = const []});
  final int totalSeconds;
  final int billableSeconds;
  final List<ProjectSlice> byProject;

  factory ReportSummary.fromMap(Map<String, dynamic> m, List<Map<String, dynamic>> entries) {
    final byProj = <int, ProjectSlice>{};
    var total = 0, billable = 0;
    for (final em in entries) {
      final e = TimeEntry.fromMap(em);
      final d = e.duration.inSeconds;
      total += d;
      if (e.billable) billable += d;
      final pid = e.projectId ?? -1;
      final name = e.projectName ?? 'Other';
      byProj.update(pid, (s) => ProjectSlice(name, s.seconds + d),
          ifAbsent: () => ProjectSlice(name, d));
    }
    final fromApi = m['total_seconds'] ?? m['totalSeconds'];
    if (fromApi is num && fromApi > total) total = fromApi.toInt();
    final slices = byProj.values.toList()..sort((a, b) => b.seconds - a.seconds);
    return ReportSummary(
      totalSeconds: total,
      billableSeconds: billable,
      byProject: slices,
    );
  }
}

class ProjectSlice {
  ProjectSlice(this.name, this.seconds);
  final String name;
  final int seconds;
}

// ---- helpers ----
int _toInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
int? _toNullableInt(dynamic v) =>
    v == null ? null : (v is int ? v : int.tryParse('$v'));
DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v * (v > 1e12 ? 1 : 1000));
  return DateTime.tryParse('$v')?.toLocal();
}

// ---- formatting ----
String hms(Duration d) {
  final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String hm(Duration d) {
  final h = d.inHours, m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  return '$h:${m.toString().padLeft(2, '0')}';
}
