import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/ui.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksForProjectProvider(project.id));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop()),
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [ProjectTile.colorFor(project.name), const Color(0xFF0055D4)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(project.name, style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text([
                if (project.clientName != null) project.clientName!,
                if (project.billable) 'Billable',
              ].join(' · '),
                  style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 14)),
              const SizedBox(height: 16),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () =>
                      ref.read(timerProvider.notifier).start(projectId: project.id),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      PlayGlyph(),
                      SizedBox(width: 8),
                      Text('Start tracking', style: TextStyle(
                          color: T.blue, fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SectionTitle('Tasks'),
        tasks.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Group(children: [
            GRow(child: Text('Could not load tasks', style: TextStyle(color: sub(context)))),
          ]),
          data: (list) => Group(children: [
            if (list.isEmpty)
              Padding(padding: const EdgeInsets.all(20),
                  child: Center(child: Text('No tasks on this project.',
                      style: TextStyle(color: sub(context), fontSize: 14)))),
            for (final t in list)
              GRow(
                onTap: () =>
                    ref.read(timerProvider.notifier).start(projectId: project.id, taskId: t.id),
                child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15,
                        color: t.status != null && t.status!.toLowerCase() == 'done'
                            ? sub(context) : ink(context))),
                trailing: t.status != null && t.status!.toLowerCase() == 'done'
                    ? const ChipTag('✓', color: ChipColor.green)
                    : const PlayGlyph(),
              ),
          ]),
        ),
        const SectionTitle('Recent entries'),
        _recentEntries(ref, context),
      ]),
    );
  }

  Widget _recentEntries(WidgetRef ref, BuildContext context) {
    final all = ref.watch(recentEntriesProvider(14)).value ?? [];
    final mine = all.where((e) => e.projectId == project.id).take(8).toList();
    if (mine.isEmpty) {
      return Group(children: [
        Padding(padding: const EdgeInsets.all(20),
            child: Center(child: Text('No recent entries.',
                style: TextStyle(color: sub(context), fontSize: 14)))),
      ]);
    }
    return Group(children: [
      for (final e in mine)
        GRow(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.taskName ?? project.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15)),
            Text(DateFormat('EEE, HH:mm').format(e.start),
                style: TextStyle(fontSize: 13, color: sub(context))),
          ]),
          trailing: Text(hm(e.duration),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ink(context))),
        ),
    ]);
  }
}
