import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/ui.dart';

class EntryDetailScreen extends ConsumerStatefulWidget {
  const EntryDetailScreen({super.key, required this.entryId, required this.initial});
  final int entryId;
  final TimeEntry initial;
  @override
  ConsumerState<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends ConsumerState<EntryDetailScreen> {
  late DateTime _start;
  late DateTime? _end;
  late bool _billable;
  late final TextEditingController _notes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start = widget.initial.start;
    _end = widget.initial.end;
    _billable = widget.initial.billable;
    _notes = TextEditingController(text: widget.initial.notes ?? '');
  }

  Duration get _duration => (_end ?? DateTime.now()).difference(_start);

  Future<void> _pickTime({required bool isStart}) async {
    final base = isStart ? _start : (_end ?? DateTime.now());
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (t == null) return;
    final newVal = DateTime(base.year, base.month, base.day, t.hour, t.minute);
    setState(() {
      if (isStart) {
        _start = newVal;
        if (_end != null && _end!.isBefore(_start)) _end = _start.add(const Duration(hours: 1));
      } else {
        _end = newVal.isBefore(_start) ? _start.add(const Duration(minutes: 15)) : newVal;
      }
    });
  }

  Future<void> _save() async {
    final api = ref.read(apiProvider);
    if (api == null) return;
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        if (widget.initial.projectId != null) 'project_id': widget.initial.projectId,
        if (widget.initial.taskId != null) 'task_id': widget.initial.taskId,
        'start_time': _start.toUtc().toIso8601String(),
        if (_end != null) 'end_time': _end!.toUtc().toIso8601String(),
        'notes': _notes.text,
        'billable': _billable,
      };
      await api.put('/api/v1/time-entries/${widget.entryId}', body);
      ref.read(entriesReloadProvider.notifier).update((v) => v + 1);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final api = ref.read(apiProvider);
    if (api == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This tracked time will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: T.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.delete('/api/v1/time-entries/${widget.entryId}');
      ref.read(entriesReloadProvider.notifier).update((v) => v + 1);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.initial;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop()),
        title: const Text('Edit Entry'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: ListView(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(vertical: 18),
          width: double.infinity,
          decoration: BoxDecoration(
            color: surface(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            Text(hm(_duration),
                style: TextStyle(
                    fontSize: 40, fontWeight: FontWeight.w200, color: ink(context))),
            const SizedBox(height: 2),
            Text(
                '${DateFormat('HH:mm').format(_start)} – ${_end != null ? DateFormat('HH:mm').format(_end!) : "now"} · ${DateFormat('EEE, MMM d').format(_start)}',
                style: TextStyle(fontSize: 13, color: sub(context))),
          ]),
        ),
        const SectionTitle('Task'),
        Group(children: [
          GRow(
            leading: ProjectTile(name: e.projectName ?? 'Project'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.displayName, style: const TextStyle(fontSize: 16)),
              if ((e.projectName ?? e.clientName) != null)
                Text([e.projectName, e.clientName].whereType<String>().join(' · '),
                    style: TextStyle(fontSize: 13, color: sub(context))),
            ]),
          ),
        ]),
        const SectionTitle('Time'),
        Group(children: [
          GRow(
            child: const Text('Start'),
            onTap: () => _pickTime(isStart: true),
            trailing: Text(DateFormat('HH:mm').format(_start),
                style: const TextStyle(color: T.blue, fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          GRow(
            child: const Text('End'),
            onTap: _end == null ? null : () => _pickTime(isStart: false),
            trailing: Text(_end == null ? 'Running' : DateFormat('HH:mm').format(_end!),
                style: TextStyle(
                    color: _end == null ? sub(context) : T.blue,
                    fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ]),
        const SectionTitle('Details'),
        Group(children: [
          GRow(
            child: const Text('Billable'),
            trailing: Switch(value: _billable, onChanged: (v) => setState(() => _billable = v)),
          ),
          GRow(
            child: const Text('Notes'),
            trailing: Text(_notes.text.isEmpty ? 'Add' : '${_notes.text.length} chars',
                style: TextStyle(fontSize: 15, color: sub(context))),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _notes,
            maxLines: 3,
            style: TextStyle(fontSize: 15, color: ink(context)),
            decoration: InputDecoration(
              hintText: 'What did you work on?',
              hintStyle: TextStyle(color: sub(context)),
              filled: true,
              fillColor: surface(context),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: _delete,
            child: const Text('Delete entry',
                style: TextStyle(color: T.red, fontSize: 16, fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
