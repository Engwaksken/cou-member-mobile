import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../widgets/remote_view.dart';
import 'edit_profile_screen.dart';
import 'home_shell.dart';

/// Asks before signing out of the app on this device.
Future<void> confirmSignOut(BuildContext context, Session session) async {
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

/// Member details, profile photo, edit profile, change password and sign out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _view = GlobalKey<RemoteViewState>();
  bool _uploading = false;

  Future<Map<String, dynamic>> _load() async {
    final session = context.read<Session>();
    final data = await session.api.get('me');
    session.updateMember(Map<String, dynamic>.from(data['member'] as Map? ?? {}));
    return data;
  }

  Future<void> _editProfile() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (saved == true) _view.currentState?.reload();
  }

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<Session>();
    try {
      // Resized on the phone so uploads stay well under the server's 5 MB limit.
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1080, maxHeight: 1080, imageQuality: 85);
      if (file == null) return;
      setState(() => _uploading = true);
      final data = await session.api.upload('update_photo', 'photo', await file.readAsBytes(), file.name);
      session.updateMember(Map<String, dynamic>.from(data['member'] as Map? ?? {}));
      messenger.showSnackBar(SnackBar(content: Text(asText(data['message'], 'Photo updated.'))));
      _view.currentState?.reload();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint('Photo upload failed: $e');
      messenger.showSnackBar(const SnackBar(content: Text('Could not use that photo. Please try another.')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: const Text('My Profile')),
      body: RemoteView(
        key: _view,
        load: _load,
        builder: (context, data) {
          final m = Map<String, dynamic>.from(data['member'] as Map? ?? {});
          final name = asText(m['full_name'], 'Member');
          final photo = asText(m['photo_url']);
          final scheme = Theme.of(context).colorScheme;
          final rows = {
            'Membership No': m['member_no'],
            'Pledge No': m['pledge_no'],
            'Church zone': m['church_zone'],
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
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      foregroundImage: photo.isEmpty ? null : NetworkImage(photo),
                      child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 36)),
                    ),
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: IconButton.filled(
                        key: const Key('changePhoto'),
                        tooltip: 'Change photo',
                        onPressed: _uploading ? null : _changePhoto,
                        icon: _uploading
                            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary))
                            : const Icon(Icons.photo_camera, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
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
                'To correct your name, membership number or department, please contact the church office.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      key: const Key('editProfile'),
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Edit profile'),
                      subtitle: const Text('Phone, email, church zone and service'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _editProfile,
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_reset),
                      title: const Text('Change password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                    ),
                    ListTile(
                      leading: Icon(Icons.logout, color: scheme.error),
                      title: Text('Sign out', style: TextStyle(color: scheme.error)),
                      onTap: () => confirmSignOut(context, session),
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
