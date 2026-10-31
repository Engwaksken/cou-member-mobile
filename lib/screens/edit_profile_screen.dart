import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/session.dart';
import 'login_screen.dart' show FormAlert;

/// Edit contact details and church zone, with the same rules as the member website.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _service;
  int? _zoneId;
  List<Map<String, dynamic>> _zones = const [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final m = context.read<Session>().member;
    _phone = TextEditingController(text: asText(m['phone']));
    _email = TextEditingController(text: asText(m['email']));
    _service = TextEditingController(text: asText(m['service_attended']));
    _zoneId = int.tryParse(asText(m['church_zone_id']));
    _loadZones();
  }

  Future<void> _loadZones() async {
    try {
      final data = await context.read<Session>().api.get('zones');
      if (!mounted) return;
      setState(() => _zones = List<Map<String, dynamic>>.from(data['items'] as List? ?? []));
    } on ApiException {
      // The zone list is optional; the member can still save their other details.
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<Session>();
    try {
      final data = await session.api.post('update_profile', {
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'service_attended': _service.text.trim(),
        'church_zone_id': _zoneId ?? 0,
      });
      session.updateMember(Map<String, dynamic>.from(data['member'] as Map? ?? {}));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(asText(data['message'], 'Profile updated.'))));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Until the zone list loads (or if the member's zone is missing from it), show "Not set" rather than an invalid value.
    final zoneValue = _zones.any((z) => z['id'] == _zoneId) ? _zoneId : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
              child: Text(
                'Keep your contact details up to date so the church can reach you.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            if (_error != null) FormAlert(text: _error!, color: Theme.of(context).colorScheme.errorContainer, icon: Icons.error_outline),
            TextFormField(
              key: const Key('phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Phone number is required.';
                if (!RegExp(r'^[0-9+\-\s()]{7,25}$').hasMatch(value)) return 'Enter a valid phone number.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'Enter a valid email address.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              key: ValueKey('zone-${_zones.length}'),
              initialValue: zoneValue,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Church zone', prefixIcon: Icon(Icons.map_outlined)),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Not set')),
                for (final z in _zones) DropdownMenuItem<int?>(value: z['id'] as int, child: Text(asText(z['name']))),
              ],
              onChanged: (v) => setState(() => _zoneId = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _service,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Service attended (optional)', prefixIcon: Icon(Icons.church_outlined)),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('saveProfile'),
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Saving…' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
