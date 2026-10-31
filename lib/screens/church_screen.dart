import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../widgets/remote_view.dart';
import '../widgets/ui.dart';
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
                leading: AnnouncementIcon(asText(a['priority'])),
                badge: Pill.priority(asText(a['priority'])),
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
                leading: DateBadge(p['program_date']),
                badge: asText(p['program_type']).isEmpty ? null : Pill(asText(p['program_type'])),
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
                leading: IconBadge(dept == 'health' ? Icons.health_and_safety_outlined : Icons.school_outlined),
              ),
          ],
        );
      },
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.title, required this.meta, required this.body, required this.leading, this.badge});

  final String title;
  final String meta;
  final String body;
  final Widget leading;
  final Widget? badge;

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
                leading,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(meta, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5)),
                      if (badge != null) ...[const SizedBox(height: 8), badge!],
                    ],
                  ),
                ),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Text(body, style: const TextStyle(height: 1.5, fontSize: 15)),
            ],
          ],
        ),
      ),
    );
  }
}
