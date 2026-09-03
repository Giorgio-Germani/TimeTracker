import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/ui.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          LargeHeader('Projects', trailing: IconButton(
            icon: const Icon(Icons.add, size: 28, color: T.blue),
            onPressed: () => _newProject(context, ref),
          )),
          projects.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Group(children: [
              GRow(child: Text('Could not load projects',
                  style: TextStyle(color: sub(context)))),
            ]),
            data: (list) {
              if (list.isEmpty) {
                return Group(children: [
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Center(child: Text('No projects yet.',
                        style: TextStyle(color: sub(context), fontSize: 15))),
                  ),
                ]);
              }
              final active = list.where((p) => !p.isArchived).toList();
              final archived = list.where((p) => p.isArchived).toList();
              return Column(children: [
                Group(children: [
                  for (final p in active)
                    GRow(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ProjectDetailScreen(project: p))),
                      leading: ProjectTile(name: p.name),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16)),
                        if (p.clientName != null)
                          Text(p.clientName!,
                              style: TextStyle(fontSize: 13, color: sub(context))),
                      ]),
                      trailing: const Chev(),
                    ),
                ]),
                if (archived.isNotEmpty) ...[
                  const SectionTitle('Archived'),
                  Group(children: [
                    for (final p in archived)
                      GRow(
                        leading: ProjectTile(name: p.name),
                        child: Text(p.name,
                            style: TextStyle(fontSize: 16, color: sub(context))),
                        trailing: const ChipTag('Archived'),
                      ),
                  ]),
                ],
              ]);
            },
          ),
        ]),
      ),
    );
  }

  void _newProject(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('New project'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Project name'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            final api = ref.read(apiProvider);
            final name = controller.text.trim();
            if (api == null || name.isEmpty) return;
            Navigator.pop(ctx);
            try {
              await api.post('/api/v1/projects', {'name': name});
              ref.invalidate(projectsProvider);
            } catch (_) {}
          },
          child: const Text('Create'),
        ),
      ],
    ));
  }
}
