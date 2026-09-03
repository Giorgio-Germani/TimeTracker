import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/ui.dart';
import 'login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final prefs = ref.watch(prefsProvider).value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          const LargeHeader('Settings'),
          Group(children: [
            GRow(
              leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: T.blue,
                  child: const Text('U',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('My account', style: TextStyle(fontSize: 16)),
                Text(api?.baseUrl ?? '', style: TextStyle(fontSize: 13, color: sub(context))),
              ]),
              trailing: const ChipTag('Connected', color: ChipColor.green),
            ),
          ]),
          const SectionTitle('Tracking'),
          Group(children: [
            GRow(
              child: const Text('Idle detection'),
              trailing: Switch(
                value: prefs?.idleDetection ?? true,
                onChanged: (v) => _setPref(ref, 'idle_detection', v),
              ),
            ),
            GRow(
              child: const Text('Idle timeout'),
              trailing: Text('${prefs?.idleTimeoutMin ?? 30} min',
                  style: TextStyle(fontSize: 15, color: sub(context))),
            ),
            GRow(
              child: const Text('Default entries to billable'),
              trailing: Switch(
                value: prefs?.defaultBillable ?? false,
                onChanged: (v) => _setPref(ref, 'default_billable', v),
              ),
            ),
          ]),
          const SectionTitle('Appearance'),
          Group(children: [
            GRow(
              child: const Text('Theme'),
              trailing: Text('System', style: TextStyle(fontSize: 15, color: sub(context))),
              onTap: () {},
            ),
          ]),
          const SectionTitle('Data'),
          Group(children: [
            const GRow(
              child: Text('Offline sync'),
              trailing: ChipTag('Up to date', color: ChipColor.green),
            ),
            GRow(
              child: const Text('Export all data'),
              trailing: const Chev(),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export — coming in the next iteration.'))),
            ),
          ]),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BigButton(
              label: 'Sign out',
              color: T.red,
              onTap: () async {
                final api = ref.read(apiProvider);
                await api?.logout();
                api?.close();
                if (context.mounted) {
                  ref.read(apiProvider.notifier).state = null;
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text('TimeTracker v2 · works with TimeTracker v5+',
              style: TextStyle(fontSize: 12, color: sub(context)))),
        ]),
      ),
    );
  }

  void _setPref(WidgetRef ref, String key, dynamic value) {
    final prefs = ref.read(prefsProvider).value;
    prefs?.set(key, value);
    ref.invalidate(prefsProvider);
  }
}
