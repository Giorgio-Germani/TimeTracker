import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../root.dart';
import '../widgets/ui.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _base = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _busy = true; _error = null; });
    try {
      final api = await Api.login(_base.text, _user.text, _pass.text);
      ref.read(apiProvider.notifier).state = api;
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute(builder: (_) => const RootShell()),
        );
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                width: 86, height: 86,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [T.blue, Color(0xFF0055D4)]),
                  boxShadow: [
                    BoxShadow(color: T.blue.withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 12)),
                  ],
                ),
                child: const Icon(Icons.access_time, color: Colors.white, size: 44),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: Text('TimeTracker',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                    letterSpacing: -.4, color: ink(context)))),
            const SizedBox(height: 4),
            Center(child: Text('Connect to your server to begin',
                style: TextStyle(fontSize: 14, color: sub(context)))),
            const SizedBox(height: 36),
            _field(_base, 'Server address · myserver.local:8080', keyboardType: .url),
            _field(_user, 'Username or email'),
            _field(_pass, 'Password', obscure: true),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: T.red, fontSize: 14),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            _busy
                ? const Center(child: CircularProgressIndicator())
                : BigButton(label: 'Sign in', onTap: _signIn),
            const SizedBox(height: 40),
            Center(child: Text('Works with self-hosted TimeTracker v5+',
                style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? T.secondary : T.tertiary))),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint,
      {bool obscure = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboardType,
        autocorrect: false,
        style: TextStyle(fontSize: 15, color: ink(context)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: sub(context), fontSize: 15),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2C2C2E)
              : T.bg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
