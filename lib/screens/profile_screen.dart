import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../widgets/remote_view.dart';

/// Member details, change password and sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: RemoteView(
        load: () => session.api.get('me'),
        builder: (context, data) {
          final m = Map<String, dynamic>.from(data['member'] as Map? ?? {});
          final name = asText(m['full_name'], 'Member');
          final rows = {
            'Membership No': m['member_no'],
            'Pledge No': m['pledge_no'],
            'Service attended': m['service_attended'],
            'Phone': m['phone'],
            'Email': m['email'],
            'Department': m['department'],
            'Joined': asText(m['joined_date']).isEmpty ? null : formatDate(m['joined_date']),
          }..removeWhere((_, v) => asText(v).isEmpty);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              Center(child: CircleAvatar(radius: 40, child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 32)))),
              const SizedBox(height: 12),
              Center(child: Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [for (final e in rows.entries) ListTile(dense: true, title: Text(e.key), trailing: Text(asText(e.value)))],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'To correct your details, please contact the church office.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_reset),
                      title: const Text('Change password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                    ),
                    ListTile(
                      leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                      title: Text('Sign out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      onTap: () => _confirmSignOut(context, session),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, Session session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your membership or pledge number and password to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await session.signOut();
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Mirrors the server rules so members see problems before submitting.
  String? _validateNew(String? value) {
    final v = value ?? '';
    if (v.length < 8) return 'Use at least 8 characters.';
    if (!RegExp('[A-Z]').hasMatch(v)) return 'Include an uppercase letter.';
    if (!RegExp('[a-z]').hasMatch(v)) return 'Include a lowercase letter.';
    if (!RegExp(r'\d').hasMatch(v)) return 'Include a number.';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await context.read<Session>().api.post('change_password', {
        'current_password': _current.text,
        'new_password': _new.text,
        'confirm_password': _confirm.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(asText(data['message'], 'Password changed.'))));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!),
              ),
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: (v) => (v ?? '').isEmpty ? 'Enter your current password.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _new,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password', helperText: 'At least 8 characters, with upper and lower case letters and a number.'),
              validator: _validateNew,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm new password'),
              validator: (v) => v != _new.text ? 'The passwords do not match.' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(_busy ? 'Saving…' : 'Change password'),
            ),
            const SizedBox(height: 12),
            Text(
              'Your new password also applies to the church member website. Other devices will be signed out.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
