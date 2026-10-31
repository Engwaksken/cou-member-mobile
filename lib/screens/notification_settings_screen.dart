import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/remote_view.dart';
import '../widgets/ui.dart';
import 'notifications_screen.dart' show notificationIcon;

const _channels = [
  ('push', 'Push', Icons.notifications_active_outlined),
  ('email', 'Email', Icons.mail_outline),
  ('sms', 'SMS', Icons.sms_outlined),
];

/// Lets the member choose, per kind of notification, whether it comes by push, email or SMS.
/// Each change is saved straight away.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  /// category key -> channel -> on, as last saved or loaded.
  Map<String, Map<String, bool>>? _settings;

  Future<Map<String, dynamic>> _load() async {
    final data = await context.read<Session>().api.get('notification_settings');
    _settings = {
      for (final c in List<Map<String, dynamic>>.from(data['categories'] as List? ?? []))
        asText(c['key']): {for (final (ch, _, _) in _channels) ch: c[ch] == true},
    };
    return data;
  }

  Future<void> _toggle(String category, String channel, bool value) async {
    final settings = _settings!;
    setState(() => settings[category]![channel] = value);
    try {
      await context.read<Session>().api.post('update_notification_settings', {
        'settings': {category: settings[category]},
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => settings[category]![channel] = !value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: RemoteView(
        load: _load,
        builder: (context, data) {
          final categories = List<Map<String, dynamic>>.from(data['categories'] as List? ?? []);
          final channels = Map<String, dynamic>.from(data['channels'] as Map? ?? {});
          bool available(String ch) => (channels[ch] as Map?)?['available'] == true;
          final notes = [
            for (final (ch, label, icon) in _channels)
              if (asText((channels[ch] as Map?)?['note']).isNotEmpty) (icon, label, asText((channels[ch] as Map?)?['note']), available(ch)),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Choose how the church reaches you for each kind of message. Changes are saved straight away.',
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        for (final (icon, label, note, ok) in notes)
                          ListTile(
                            dense: true,
                            leading: Icon(icon, color: ok ? AppColors.purple : scheme.onSurfaceVariant),
                            title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(note),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              for (final c in categories)
                _CategoryCard(
                  category: c,
                  values: _settings?[asText(c['key'])] ?? const {},
                  available: available,
                  onChanged: (ch, v) => _toggle(asText(c['key']), ch, v),
                ),
              const SizedBox(height: 8),
              Text(
                'SMS messages are paid for by the church, so please keep them for what matters most to you.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.values, required this.available, required this.onChanged});

  final Map<String, dynamic> category;
  final Map<String, bool> values;
  final bool Function(String channel) available;
  final void Function(String channel, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final key = asText(category['key']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(notificationIcon(key), size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asText(category['label']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                      Text(asText(category['description']), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (ch, label, icon) in _channels)
                  FilterChip(
                    key: Key('$key-$ch'),
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    selected: values[ch] ?? false,
                    showCheckmark: false,
                    onSelected: available(ch) || (values[ch] ?? false) ? (v) => onChanged(ch, v) : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
