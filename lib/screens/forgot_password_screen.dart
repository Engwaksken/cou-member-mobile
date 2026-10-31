import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../widgets/ui.dart';
import 'login_screen.dart' show FormAlert;
import 'profile_screen.dart' show validateNewPassword;

/// Resets a forgotten password: the member asks for a code sent to the phone and email on file,
/// then enters the code and a new password. The member is signed in afterwards.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.identifier = ''});

  /// Number already typed on the sign-in screen.
  final String identifier;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _identifier = TextEditingController(text: widget.identifier.trim());
  final _code = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _info;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _code.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Password reset failed: $e');
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (_identifier.text.trim().isEmpty) {
      setState(() => _error = 'Enter your membership or pledge number.');
      return;
    }
    await _run(() async {
      final data = await context.read<Session>().api.post('forgot_password', {'identifier': _identifier.text.trim()});
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _info = asText(data['message'], 'A reset code has been sent to your phone or email.');
      });
    });
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    await _run(() async {
      final session = context.read<Session>();
      final identifier = _identifier.text.trim();
      await session.api.post('reset_password', {
        'identifier': identifier,
        'code': _code.text.trim(),
        'new_password': _new.text,
        'confirm_password': _confirm.text,
      });
      await session.signIn(identifier, _new.text);
      // The home screen replaces sign-in underneath; close this page to show it.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AuthLayout(
      title: 'Reset password',
      subtitle: _codeSent ? 'Step 2 of 2 · Enter the code and a new password' : 'Step 1 of 2 · Get a code',
      compact: true,
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) FormAlert(text: _error!, color: scheme.errorContainer, icon: Icons.error_outline),
            if (_info != null && _error == null) FormAlert(text: _info!, color: scheme.secondaryContainer, icon: Icons.mark_email_read_outlined),
            if (!_codeSent)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Enter your membership or pledge number. We will send a 6-digit code to the phone number '
                  'and email the church has for you.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            TextFormField(
              key: const Key('resetIdentifier'),
              controller: _identifier,
              enabled: !_codeSent,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _codeSent ? null : _sendCode(),
              decoration: const InputDecoration(
                labelText: 'Membership or pledge number',
                hintText: 'e.g. RCOU-2026-0001 or P-001',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),
            if (!_codeSent) ...[
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('sendCode'),
                onPressed: _busy ? null : _sendCode,
                child: Text(_busy ? 'Sending…' : 'Send code'),
              ),
            ] else ...[
              TextFormField(
                key: const Key('resetCode'),
                controller: _code,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                autofillHints: const [AutofillHints.oneTimeCode],
                style: const TextStyle(fontSize: 18, letterSpacing: 4, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(labelText: '6-digit code', prefixIcon: Icon(Icons.pin_outlined)),
                validator: (v) => (v ?? '').trim().length != 6 ? 'Enter the 6-digit code you received.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('resetNewPassword'),
                controller: _new,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: 'New password',
                  helperText: 'At least 8 characters, with upper and lower case letters and a number.',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                validator: validateNewPassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('resetConfirmPassword'),
                controller: _confirm,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _reset(),
                decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => v != _new.text ? 'The passwords do not match.' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('resetPassword'),
                onPressed: _busy ? null : _reset,
                child: Text(_busy ? 'Saving…' : 'Reset password'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : _sendCode,
                child: const Text('Send a new code'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _codeSent = false;
                          _info = null;
                          _error = null;
                          _code.clear();
                        }),
                child: const Text('Use a different number'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Your new password also applies to the church member website, and signs you out on other devices. '
              'No phone or email on file? Ask the church office to reset your password.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
