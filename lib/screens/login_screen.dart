import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/session.dart';

/// Sign in with a membership number or pledge number and the member's portal password.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().signIn(_identifier.text, _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notice = context.watch<Session>().notice;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.church, size: 72, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text(AppConfig.churchName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Member App', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 32),
                    if (notice != null && _error == null) _Alert(text: notice, color: scheme.secondaryContainer),
                    if (_error != null) _Alert(text: _error!, color: scheme.errorContainer),
                    TextFormField(
                      key: const Key('identifier'),
                      controller: _identifier,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Membership or pledge number',
                        hintText: 'e.g. RCOU-2026-0001 or P-001',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your membership or pledge number.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('password'),
                      controller: _password,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Hide password' : 'Show password',
                          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      validator: (v) => (v ?? '').isEmpty ? 'Enter your password.' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('signIn'),
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Use the same password as the church member website. '
                      'Forgot it? Ask the church office to reset it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(text),
    );
  }
}
