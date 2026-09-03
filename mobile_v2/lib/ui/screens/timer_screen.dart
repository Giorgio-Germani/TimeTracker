import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/ui.dart';
import 'entry_detail_screen.dart';
import 'start_sheet.dart';

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});
  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  DateTime _lastActivity = DateTime.now();
  bool _showIdle = false;
  Duration _idleWindow = Duration.zero;
  final List<_ReviewedIdle> _reviewed = [];

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 15), (_) => _checkIdle());
  }

  Future<void> _checkIdle() async {
    if (!mounted || _showIdle) return;
    final prefs = ref.read(prefsProvider).value;
    final timer = ref.read(timerProvider).value;
    if (timer == null || !timer.running || prefs == null || !prefs.idleDetection) {
      return;
    }
    final idle = DateTime.now().difference(_lastActivity);
    if (idle >= Duration(minutes: prefs.idleTimeoutMin)) {
      final controller = ref.read(timerProvider.notifier);
      final ctx = [
        if (controller.currentTaskName.isNotEmpty) controller.currentTaskName,
        if (controller.currentProjectName.isNotEmpty) controller.currentProjectName,
      ].join(' · ');
      setState(() {
        _showIdle = true;
        _idleWindow = idle;
      });
      await controller.stop();
      ref.read(entriesReloadProvider.notifier).update((v) => v + 1);
      _idleContext = ctx;
    }
  }

  String _idleContext = '';

  Future<void> _resolveIdle(_IdleChoice choice) async {
    final api = ref.read(apiProvider);
    setState(() => _showIdle = false);
    _lastActivity = DateTime.now();
    if (api == null) return;

    if (choice == _IdleChoice.keep) {
      if (mounted) {
        setState(() => _reviewed.add(_ReviewedIdle(_idleWindow, _idleContext, 'Kept')));
      }
      return;
    }

    // Trim or discard: find the entry that just ended today and patch/delete it.
    try {
      final today = await ref.read(entriesForDayProvider(DateTime.now()).future);
      if (today.isEmpty) return;
      final last = today.last;
      if (choice == _IdleChoice.discard) {
        await api.delete('/api/v1/time-entries/${last.id}');
        if (mounted) {
          setState(() => _reviewed.add(_ReviewedIdle(_idleWindow, _idleContext, 'Discarded')));
        }
      } else {
        final end = last.start.add(const Duration(minutes: 5));
        await api.put('/api/v1/time-entries/${last.id}',
            {'end_time': end.toUtc().toIso8601String()});
        if (mounted) {
          setState(() => _reviewed.add(_ReviewedIdle(_idleWindow, _idleContext, 'Trimmed to 5 min')));
        }
      }
      ref.read(entriesReloadProvider.notifier).update((v) => v + 1);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(timerProvider);
    final status = timer.value ?? TimerStatus();
    final recents = ref.watch(recentsProvider);
    final today = ref.watch(entriesForDayProvider(DateUtils.dateOnly(DateTime.now())));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Listener(
          onPointerDown: (_) => _lastActivity = DateTime.now(),
          onPointerMove: (_) => _lastActivity = DateTime.now(),
          child: Stack(children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                LargeHeader('Today', trailing: Text(
                  DateFormat('EEE, MMM d').format(DateTime.now()),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: T.blue),
                )),
                _Hero(status: status),
                if (_showIdle) ...[
                  _IdleCard(
                    window: _idleWindow,
                    contextText: _idleContext,
                    onKeep: () => _resolveIdle(_IdleChoice.keep),
                    onTrim: () => _resolveIdle(_IdleChoice.trim),
                    onDiscard: () => _resolveIdle(_IdleChoice.discard),
                  ),
                ],
                if (recents.isNotEmpty) ...[
                  const SectionTitle(top: 4, 'Continue working on'),
                  SizedBox(
                    height: 134,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: recents.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final e = recents[i];
                        return _RecentCard(entry: e, onStart: () {
                          ref.read(timerProvider.notifier)
                              .start(projectId: e.projectId, taskId: e.taskId);
                        });
                      },
                    ),
                  ),
                ],
                SectionTitle(top: 22, 'Today'),
                today.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Group(children: [GRow(child: Text('Could not load entries',
                      style: TextStyle(color: sub(context))))]),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return Group(children: [
                        Padding(
                          padding: const EdgeInsets.all(28),
                          child: Center(child: Text('No time tracked yet today.\nTap + to start.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: sub(context), fontSize: 15, height: 1.5))),
                        ),
                      ]);
                    }
                    final total = entries.fold<Duration>(Duration.zero, (a, e) => a + e.duration);
                    return Group(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Total ${hm(total)}',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sub(context)))),
                        ),
                        for (final e in entries)
                          _TimelineRow(entry: e, onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => EntryDetailScreen(entryId: e.id, initial: e)));
                          }),
                      ]),
                    );
                  },
                ),
                if (_reviewed.isNotEmpty) ...[
                  const SectionTitle('Reviewed idle time'),
                  Group(children: [
                    for (final r in _reviewed)
                      GRow(
                        child: Column(crossAxisAlignment: .start, children: [
                          Text('${hm(r.window)} · ${r.contextText.isEmpty ? "Idle" : r.contextText}',
                              style: const TextStyle(fontSize: 15)),
                        ]),
                        trailing: ChipTag(r.resolution,
                            color: r.resolution == 'Kept' ? ChipColor.green : ChipColor.gray),
                      ),
                  ]),
                ],
              ],
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: FloatingActionButton(
                onPressed: () => showStartSheet(context),
                backgroundColor: T.blue,
                foregroundColor: Colors.white,
                elevation: 6,
                child: const Icon(Icons.add, size: 30),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------- Hero ----------------

class _Hero extends ConsumerWidget {
  const _Hero({required this.status});
  final TimerStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = status.running;
    final controller = ref.read(timerProvider.notifier);
    final title = [
      if (controller.currentTaskName.isNotEmpty) controller.currentTaskName,
      if (controller.currentProjectName.isEmpty && running) 'Tracking',
    ].join(' — ');
    final subtitle = controller.currentProjectName;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: BoxDecoration(
        color: surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(children: [
        if (running) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: T.green, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('TRACKING', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: T.green, letterSpacing: 1)),
          ]),
        ] else
          Text('STOPPED', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sub(context), letterSpacing: 1)),
        const SizedBox(height: 8),
        StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (context, _) => Text(
            hms(running ? DateTime.now().difference(status.start!) : Duration.zero),
            style: TextStyle(
              fontSize: 58,
              fontWeight: FontWeight.w200,
              letterSpacing: -1,
              color: ink(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (running) ...[
          const SizedBox(height: 2),
          Text(title.isEmpty ? 'Working' : title,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ink(context))),
          if (subtitle.isNotEmpty)
            Text(subtitle, style: TextStyle(fontSize: 14, color: sub(context))),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => ref.read(timerProvider.notifier).stop(),
            child: Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(color: Color(0xFFFFE9E7), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Container(width: 26, height: 26, decoration: BoxDecoration(color: T.red, borderRadius: BorderRadius.circular(6))),
            ),
          ),
          const SizedBox(height: 8),
          Text('Started ${DateFormat('HH:mm').format(status.start!)}',
              style: TextStyle(fontSize: 12, color: sub(context))),
        ] else ...[
          const SizedBox(height: 6),
          Text('Nothing running', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: sub(context))),
          Text('Tap + to start tracking', style: TextStyle(fontSize: 14, color: sub(context))),
        ],
      ]),
    );
  }
}

// ---------------- Recent cards ----------------

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.entry, required this.onStart});
  final TimeEntry entry;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final name = entry.projectName ?? 'Project';
    final ago = entry.running
        ? 'now'
        : _shortAgo(DateTime.now().difference(entry.start));
    return GestureDetector(
      onTap: onStart,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 2)],
        ),
        child: Column(crossAxisAlignment: .start, children: [
          ProjectTile(name: name),
          const Spacer(),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink(context))),
          Text(ago, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: sub(context))),
          const SizedBox(height: 6),
          Row(children: [
            const PlayGlyph(),
            const SizedBox(width: 5),
            Text('Start', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: T.blue)),
          ]),
        ]),
      ),
    );
  }
}

String _shortAgo(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  final days = d.inDays;
  if (days == 1) return 'Yesterday';
  return '$days days ago';
}

// ---------------- Timeline ----------------

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.onTap});
  final TimeEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = entry.projectName ?? 'Entry';
    final isRunning = entry.running;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: sep(context), width: .5))),
        child: Row(crossAxisAlignment: .start, children: [
          SizedBox(
            width: 46,
            child: Text(DateFormat('HH:mm').format(entry.start),
                style: TextStyle(fontSize: 12, color: sub(context))),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isRunning ? T.blue : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : const Color(0xFFD1D1D6)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(crossAxisAlignment: .start, children: [
                Text(name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: isRunning ? Colors.white : ink(context))),
                Text('${DateFormat('HH:mm').format(entry.start)} – ${entry.end != null ? DateFormat('HH:mm').format(entry.end!) : "now"}',
                    style: TextStyle(fontSize: 12,
                        color: isRunning ? Colors.white.withValues(alpha: .85) : sub(context))),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(hm(entry.duration),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink(context))),
          ),
        ]),
      ),
    );
  }
}

// ---------------- Idle review ----------------

enum _IdleChoice { keep, trim, discard }

class _ReviewedIdle {
  _ReviewedIdle(this.window, this.contextText, this.resolution);
  final Duration window;
  final String contextText;
  final String resolution;
}

class _IdleCard extends StatelessWidget {
  const _IdleCard({
    required this.window,
    required this.contextText,
    required this.onKeep,
    required this.onTrim,
    required this.onDiscard,
  });

  final Duration window;
  final String contextText;
  final VoidCallback onKeep;
  final VoidCallback onTrim;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [T.orange, Color(0xFFFF6B22)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: .start, children: [
        Row(children: [
          const Icon(Icons.schedule, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: .start, children: [
              const Text('Was this time real work?',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              Text('The timer ran ${hm(window)} while your device was idle.'
                  '${contextText.isEmpty ? "" : " · $contextText"}',
                  style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 13)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _idleBtn('Keep', T.greenDark, onKeep),
          const SizedBox(width: 8),
          _idleBtn('Trim to 5 min', T.orange, onTrim),
          const SizedBox(width: 8),
          _idleBtn('Discard', T.red, onDiscard),
        ]),
      ]),
    );
  }

  Widget _idleBtn(String label, Color color, VoidCallback onTap) => Expanded(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Center(
                child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      );
}
