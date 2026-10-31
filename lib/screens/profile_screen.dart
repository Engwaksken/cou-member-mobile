import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/remote_view.dart';
import '../widgets/ui.dart';
import 'edit_profile_screen.dart';
import 'home_shell.dart';
import 'notification_settings_screen.dart';
import 'login_screen.dart' show FormAlert;

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
            ('Membership No', Icons.badge_outlined): m['member_no'],
            ('Pledge No', Icons.handshake_outlined): m['pledge_no'],
            ('Church zone', Icons.map_outlined): m['church_zone'],
            ('Service attended', Icons.church_outlined): m['service_attended'],
            ('Phone', Icons.phone_outlined): m['phone'],
            ('Email', Icons.email_outlined): m['email'],
            ('Department', Icons.groups_outlined): m['department'],
            ('Joined', Icons.event_available_outlined): asText(m['joined_date']).isEmpty ? null : formatDate(m['joined_date']),
          }..removeWhere((_, v) => asText(v).isEmpty);
          // A short page, built in full rather than lazily.
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BrandPanel(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                            child: CircleAvatar(
                              radius: 46,
                              backgroundColor: Colors.white,
                              foregroundImage: photo.isEmpty ? null : NetworkImage(photo),
                              child: Text(
                                name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.purple),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -8,
                            bottom: -8,
                            child: IconButton.filled(
                              key: const Key('changePhoto'),
                              tooltip: 'Change photo',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.purple,
                                disabledBackgroundColor: Colors.white,
                                side: const BorderSide(color: AppColors.purple, width: 2),
                              ),
                              onPressed: _uploading ? null : _changePhoto,
                              icon: _uploading
                                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary))
                                  : const Icon(Icons.photo_camera, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Church of Uganda member',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: .85)),
                      ),
                    ],
                  ),
                ),
                if (rows.isNotEmpty) ...[
                  const SectionTitle('My details'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [for (final e in rows.entries) DetailRow(icon: e.key.$2, label: e.key.$1, value: asText(e.value))],
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Text(
                    'To correct your name, membership number or department, please contact the church office.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  ),
                ),
                const SectionTitle('Account'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        key: const Key('editProfile'),
                        leading: const IconBadge(Icons.edit_outlined, size: 40),
                        title: const Text('Edit profile'),
                        subtitle: const Text('Phone, email, church zone and service'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _editProfile,
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        leading: const IconBadge(Icons.lock_reset, size: 40),
                        title: const Text('Change password'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      ListTile(
                        key: const Key('openNotificationSettings'),
                        leading: const IconBadge(Icons.notifications_outlined, size: 40),
                        title: const Text('Notification settings'),
                        subtitle: const Text('Push, email and SMS'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error.withValues(alpha: .4), width: 1.4),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                  onPressed: () => confirmSignOut(context, session),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Mirrors the server password rules so members see problems before submitting.
String? validateNewPassword(String? value) {
  final v = value ?? '';
  if (v.length < 8) return 'Use at least 8 characters.';
  if (!RegExp('[A-Z]').hasMatch(v)) return 'Include an uppercase letter.';
  if (!RegExp('[a-z]').hasMatch(v)) return 'Include a lowercase letter.';
  if (!RegExp(r'\d').hasMatch(v)) return 'Include a number.';
  return null;
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
            if (_error != null) FormAlert(text: _error!, color: Theme.of(context).colorScheme.errorContainer, icon: Icons.error_outline),
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password', prefixIcon: Icon(Icons.lock_outline)),
              validator: (v) => (v ?? '').isEmpty ? 'Enter your current password.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _new,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText: 'At least 8 characters, with upper and lower case letters and a number.',
                prefixIcon: Icon(Icons.lock_reset),
              ),
              validator: validateNewPassword,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_reset)),
              validator: (v) => v != _new.text ? 'The passwords do not match.' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Saving…' : 'Change password')),
            const SizedBox(height: 16),
            Text(
              'Your new password also applies to the church member website. Other devices will be signed out.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
