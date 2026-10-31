import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/push.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/remote_view.dart';
import '../widgets/ui.dart';
import 'notification_settings_screen.dart';

/// Icon for each notification category (same keys as the server's categories).
IconData notificationIcon(String category) => switch (category) {
      'announcements' => Icons.campaign_outlined,
      'events' => Icons.celebration_outlined,
      'programs' => Icons.event_outlined,
      'tips' => Icons.health_and_safety_outlined,
      'pledges' => Icons.handshake_outlined,
      'payments' => Icons.payments_outlined,
      'reminders' => Icons.alarm_outlined,
      _ => Icons.notifications_outlined,
    };

/// The member's recent notifications. Opening the page marks them as read.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            key: const Key('notificationSettings'),
            tooltip: 'Notification settings',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
          ),
        ],
      ),
      body: RemoteView(
        load: () async {
          final data = await api.get('notifications');
          if (((data['unread'] as num?) ?? 0) > 0) {
            try {
              await api.post('mark_notifications_read', const {});
              unreadNotifications.value = 0;
            } catch (e) {
              debugPrint('Could not mark notifications as read: $e');
            }
          }
          return data;
        },
        builder: (context, data) {
          final items = List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                MessageView(icon: Icons.notifications_none, message: 'No notifications yet. New announcements, programs and payments will show here.'),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: items.length,
            itemBuilder: (context, i) => _NotificationCard(item: items[i]),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = item['read_at'] == null;
    return Card(
      color: unread ? AppColors.goldSoft.withValues(alpha: .55) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(notificationIcon(asText(item['category'])), size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asText(item['title']), style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(asText(item['body']), style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35)),
                  const SizedBox(height: 6),
                  Text(formatDate(item['created_at'], 'd MMM y · HH:mm'), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bell for app bars, with the unread count.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: unreadNotifications,
      builder: (context, unread, _) => IconButton(
        key: const Key('notificationBell'),
        tooltip: 'Notifications',
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 99 ? '99+' : '$unread'),
          child: const Icon(Icons.notifications_outlined),
        ),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      ),
    );
  }
}
