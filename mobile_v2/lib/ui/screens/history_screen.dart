import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/ui.dart';
import 'entry_detail_screen.dart';
import 'start_sheet.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _month = DateTime.now();
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final day = _selected ?? DateTime.now();
    final entries = ref.watch(entriesForDayProvider(DateUtils.dateOnly(day)));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              LargeHeader('History', trailing: TextButton(
                onPressed: () => _showFilterSheet(),
                child: const Text('Filter', style: TextStyle(fontSize: 15)),
              )),
              _calendar(),
              SectionTitle(
                  '${DateFormat('EEEE, MMM d').format(day)} · ${entries.value == null ? "…" : _dayTotal(entries.value!)}'),
              entries.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Group(children: [
                  GRow(child: Text('Could not load entries',
                      style: TextStyle(color: sub(context)))),
                ]),
                data: (list) {
                  if (list.isEmpty) {
                    return Group(children: [
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(child: Text('No time tracked on this day.',
                            style: TextStyle(color: sub(context), fontSize: 15))),
                      ),
                    ]);
                  }
                  return Group(children: [
                    for (final e in list)
                      GRow(
                        leading: ProjectTile(name: e.projectName ?? 'Entry'),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => EntryDetailScreen(entryId: e.id, initial: e))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.displayName,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16)),
                          Text(
                              '${DateFormat('HH:mm').format(e.start)} – ${e.end != null ? DateFormat('HH:mm').format(e.end!) : "now"}'
                              '${e.projectName != null && e.taskName != null ? " · ${e.projectName}" : ""}',
                              style: TextStyle(fontSize: 13, color: sub(context))),
                        ]),
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(hm(e.duration),
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ink(context))),
                          const SizedBox(height: 3),
                          if (e.running)
                            const ChipTag('Running', color: ChipColor.blue)
                          else if (e.billable)
                            const ChipTag('Billable', color: ChipColor.green),
                        ]),
                      ),
                    // Restart shortcut row for the last entry
                    GRow(
                      onTap: () {
                        final last = list.last;
                        ref.read(timerProvider.notifier).start(
                            projectId: last.projectId, taskId: last.taskId);
                      },
                      child: Row(children: [
                        const PlayGlyph(),
                        const SizedBox(width: 8),
                        Text('Restart last entry',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: T.blue)),
                      ]),
                    ),
                  ]);
                },
              ),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: FloatingActionButton(
              onPressed: () => showStartSheet(context),
              backgroundColor: T.blue,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add, size: 30),
            ),
          ),
        ]),
      ),
    );
  }

  String _dayTotal(List<TimeEntry> list) {
    final d = list.fold<Duration>(Duration.zero, (a, e) => a + e.duration);
    return '${hm(d)} · ${list.length} ${list.length == 1 ? "entry" : "entries"}';
  }

  Widget _calendar() {
    final days = <DateTime>[];
    final first = DateTime(_month.year, _month.month, 1);
    final lead = first.weekday - 1; // Monday first
    for (var i = 0; i < lead; i++) {
      days.add(first.subtract(Duration(days: lead - i)));
    }
    var d = first;
    while (d.month == _month.month) {
      days.add(d);
      d = DateTime(d.year, d.month, d.day + 1);
    }
    while (days.length % 7 != 0) {
      days.add(DateTime(d.year, d.month, d.day + (days.length % 7)));
    }

    final today = DateUtils.dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 2)],
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
                icon: const Icon(Icons.chevron_left, color: T.blue),
                onPressed: () => setState(() =>
                    _month = DateTime(_month.year, _month.month - 1, 1))),
            Text(DateFormat('MMMM yyyy').format(_month),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink(context))),
            IconButton(
                icon: const Icon(Icons.chevron_right, color: T.blue),
                onPressed: () => setState(() =>
                    _month = DateTime(_month.year, _month.month + 1, 1))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            for (final dow in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(child: Center(child: Text(dow,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sub(context))))),
          ]),
          const SizedBox(height: 6),
          for (var w = 0; w < days.length / 7; w++)
            Row(children: [
              for (var i = 0; i < 7; i++) _dayCell(days[w * 7 + i], today),
            ]),
        ]),
      ),
    );
  }

  Widget _dayCell(DateTime day, DateTime today) {
    final inMonth = day.month == _month.month;
    final isSel = _selected != null && DateUtils.dateOnly(day) == DateUtils.dateOnly(_selected!);
    final isToday = day == today;
    final future = day.isAfter(today);
    return Expanded(
      child: GestureDetector(
        onTap: future || !inMonth ? null : () => setState(() => _selected = day),
        child: Container(
          height: 38,
          margin: const EdgeInsets.symmetric(vertical: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSel ? T.blue : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text('${day.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSel || isToday ? FontWeight.w700 : FontWeight.w500,
                color: isSel
                    ? Colors.white
                    : future || !inMonth
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF48484A)
                            : T.tertiary)
                        : isToday
                            ? T.blue
                            : ink(context),
              )),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Filters (project, billable) — coming in the next iteration.')));
  }
}
