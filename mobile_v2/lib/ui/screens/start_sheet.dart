import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/ui.dart';

Future<void> showStartSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : T.sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const StartSheet(),
  );
}

class StartSheet extends ConsumerStatefulWidget {
  const StartSheet({super.key});
  @override
  ConsumerState<StartSheet> createState() => _StartSheetState();
}

enum _StartTab { recent, all }

class _StartSheetState extends ConsumerState<StartSheet> {
  _StartTab _tab = _StartTab.recent;
  String _query = '';
  int? _selectedProject;
  int? _selectedTask;
  String? _selectedLabel;

  @override
  Widget build(BuildContext context) {
    final recents = ref.watch(recentsProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final projects =
        (projectsAsync.value ?? []).where((p) => !p.isArchived).toList();

    final filtered = _query.isEmpty
        ? projects
        : projects
            .where((p) =>
                p.name.toLowerCase().contains(_query) ||
                (p.clientName ?? '').toLowerCase().contains(_query))
            .toList();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 38, height: 5, decoration: BoxDecoration(
              color: T.tertiary, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 12),
          Text('What are you working on?',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: ink(context))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() {
                _query = v.toLowerCase();
                if (_query.isNotEmpty) _tab = _StartTab.all;
              }),
              style: TextStyle(fontSize: 15, color: ink(context)),
              decoration: InputDecoration(
                hintText: 'Search projects & tasks',
                hintStyle: TextStyle(color: sub(context)),
                prefixIcon: Icon(Icons.search, color: sub(context)),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2C2C2E)
                    : T.fieldBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2C2C2E)
                    : T.fieldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                _seg('Recent', _StartTab.recent),
                _seg('All', _StartTab.all),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: surface(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    if (_tab == _StartTab.recent && _query.isEmpty) ...[
                      if (recents.isEmpty)
                        _empty('No recent work yet'),
                      for (final e in recents)
                        _option(
                          name: e.taskName ?? e.projectName ?? 'Entry',
                          subtitle: [e.projectName, e.clientName].whereType<String>().join(' · '),
                          tileName: e.projectName ?? '?',
                          selected: _selectedProject == e.projectId && _selectedTask == e.taskId,
                          onTap: () => setState(() {
                            _selectedProject = e.projectId;
                            _selectedTask = e.taskId;
                            _selectedLabel = e.taskName ?? e.projectName;
                          }),
                        ),
                    ] else ...[
                      if (filtered.isEmpty) _empty('No projects'),
                      for (final p in filtered) ...[
                        _option(
                          name: p.name,
                          subtitle: p.clientName ?? (p.billable ? 'Billable' : ''),
                          tileName: p.name,
                          selected: _selectedProject == p.id && _selectedTask == null,
                          onTap: () => setState(() {
                            _selectedProject = p.id;
                            _selectedTask = null;
                            _selectedLabel = p.name;
                          }),
                        ),
                        _ProjectTasks(projectId: p.id,
                          selectedTask: _selectedTask,
                          onSelect: (t) => setState(() {
                            _selectedProject = p.id;
                            _selectedTask = t.id;
                            _selectedLabel = t.name;
                          }),
                        ),
                      ],
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                BigButton(
                  label: _selectedLabel == null
                      ? 'Select a project to start'
                      : 'Start tracking  ·  $_selectedLabel',
                  color: _selectedLabel == null ? T.tertiary : T.blue,
                  onTap: _selectedLabel == null
                      ? null
                      : () {
                          ref.read(timerProvider.notifier).start(
                              projectId: _selectedProject, taskId: _selectedTask);
                          Navigator.of(context).pop();
                        },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _seg(String label, _StartTab tab) {
    final on = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: on ? surface(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: on ? [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 3)] : null,
          ),
          child: Center(child: Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: on ? ink(context) : sub(context)))),
        ),
      ),
    );
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(text, style: TextStyle(color: sub(context)))),
      );

  Widget _option({
    required String name,
    required String subtitle,
    required String tileName,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: sep(context), width: .5))),
        child: Row(children: [
          ProjectTile(name: tileName),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: ink(context))),
            if (subtitle.isNotEmpty)
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: sub(context))),
          ])),
          if (selected) const Icon(Icons.check_circle, color: T.blue, size: 22),
        ]),
      ),
    );
  }
}

/// Inline task expander: shown under each project; tap task row to select.
class _ProjectTasks extends ConsumerWidget {
  const _ProjectTasks({
    required this.projectId,
    required this.selectedTask,
    required this.onSelect,
  });

  final int projectId;
  final int? selectedTask;
  final void Function(Task) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksForProjectProvider(projectId));
    return tasks.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(children: [
          for (final t in list.take(4))
            InkWell(
              onTap: () => onSelect(t),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(left: 54, right: 12, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: sep(context), width: .5)),
                ),
                child: Row(children: [
                  Expanded(child: Text(t.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: ink(context)))),
                  if (selectedTask == t.id)
                    const Icon(Icons.check_circle, color: T.blue, size: 20),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}
