import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../widgets/remote_view.dart';
import 'home_shell.dart';

/// Church news: announcements, upcoming programs, and Health/Education department tips.
class ChurchScreen extends StatelessWidget {
  const ChurchScreen({super.key, this.initialTab = 0});

  /// Tab to show first.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab.clamp(0, 4 - 1),
      child: Scaffold(
        appBar: AppBar(
          leading: const MenuButton(),
          title: const Text('Church'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [Tab(text: 'Announcements'), Tab(text: 'Programs'), Tab(text: 'Health Tips'), Tab(text: 'Education Tips')],
          ),
        ),
        body: const TabBarView(
          children: [_AnnouncementsTab(), _ProgramsTab(), _TipsTab(dept: 'health'), _TipsTab(dept: 'education')],
        ),
      ),
    );
  }
}

class _AnnouncementsTab extends StatelessWidget {
  const _AnnouncementsTab();

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return RemoteView(
      load: () => api.get('announcements'),
      builder: (context, data) {
        final items = List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
        if (items.isEmpty) return const MessageView(icon: Icons.notifications_none, message: 'No announcements right now.');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final a in items)
              _ArticleCard(
                title: asText(a['title']),
                meta: formatDate(a['published_at']),
                body: asText(a['message']),
                badge: asText(a['priority']) == 'Normal' ? null : asText(a['priority']),
                badgeColor: asText(a['priority']) == 'Urgent' ? Colors.red.shade100 : Colors.amber.shade100,
              ),
          ],
        );
      },
    );
  }
}

class _ProgramsTab extends StatelessWidget {
  const _ProgramsTab();

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return RemoteView(
      load: () => api.get('programs'),
      builder: (context, data) {
        final items = List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
        if (items.isEmpty) return const MessageView(icon: Icons.event_busy, message: 'No upcoming programs.');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final p in items)
              _ArticleCard(
                title: asText(p['title']),
                meta: [
                  formatDate(p['program_date'], 'EEE d MMM y'),
                  [formatTime(p['start_time']), formatTime(p['end_time'])].where((s) => s.isNotEmpty).join('–'),
                  asText(p['venue']),
                ].where((s) => s.isNotEmpty).join(' · '),
                body: [asText(p['description']), if (asText(p['meeting_link']).isNotEmpty) 'Online: ${p['meeting_link']}'].where((s) => s.isNotEmpty).join('\n\n'),
                badge: asText(p['program_type']).isEmpty ? null : asText(p['program_type']),
              ),
          ],
        );
      },
    );
  }
}

class _TipsTab extends StatelessWidget {
  const _TipsTab({required this.dept});

  final String dept;

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return RemoteView(
      load: () => api.get('tips', {'dept': dept}),
      builder: (context, data) {
        final items = List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
        final department = asText(data['department']);
        if (items.isEmpty) return MessageView(icon: Icons.lightbulb_outline, message: 'No $department tips have been published yet.');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final t in items)
              _ArticleCard(
                title: asText(t['title']),
                meta: '$department · ${asText(t['author'])} · ${formatDate(t['published_at'])}',
                body: asText(t['content']),
              ),
          ],
        );
      },
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.title, required this.meta, required this.body, this.badge, this.badgeColor});

  final String title;
  final String meta;
  final String body;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scheme.primary))),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: badgeColor ?? scheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                    child: Text(badge!, style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(meta, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            if (body.isNotEmpty) ...[const SizedBox(height: 10), Text(body, style: const TextStyle(height: 1.45))],
          ],
        ),
      ),
    );
  }
}
