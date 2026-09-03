import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/api.dart';
import 'core/theme.dart';
import 'ui/root.dart';
import 'ui/screens/login_screen.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = await Api.restore();
  runApp(ProviderScope(
    overrides: [apiProvider.overrideWith((ref) => api)],
    child: const TimeTrackerApp(),
  ));
}

class TimeTrackerApp extends ConsumerWidget {
  const TimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return MaterialApp(
      title: 'TimeTracker',
      debugShowCheckedModeBanner: false,
      theme: T.theme(Brightness.light),
      darkTheme: T.theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: api == null ? const LoginScreen() : const RootShell(),
    );
  }
}
