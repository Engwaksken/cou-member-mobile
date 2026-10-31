import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/session.dart';
import '../widgets/ui.dart';
import 'forgot_password_screen.dart';

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
    } catch (e) {
      debugPrint('Sign-in failed: $e');
      if (mounted) setState(() => _error = 'Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notice = context.watch<Session>().notice;
    return AuthLayout(
      title: AppConfig.churchName,
      subtitle: 'Member App',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Sign in with your membership or pledge number.', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            if (notice != null && _error == null) FormAlert(text: notice, color: scheme.secondaryContainer),
            if (_error != null) FormAlert(text: _error!, color: scheme.errorContainer, icon: Icons.error_outline),
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
                  icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              validator: (v) => (v ?? '').isEmpty ? 'Enter your password.' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('forgotPassword'),
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => ForgotPasswordScreen(identifier: _identifier.text)),
                        ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 4),
            FilledButton(
              key: const Key('signIn'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.primary))
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 20),
            Text(
              'Use the same password as the church member website.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coloured message box above a form.
class FormAlert extends StatelessWidget {
  const FormAlert({super.key, required this.text, required this.color, this.icon = Icons.info_outline});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.35))),
        ],
      ),
    );
  }
}
