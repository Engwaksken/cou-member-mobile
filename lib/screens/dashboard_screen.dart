import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/remote_view.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';
import 'notifications_screen.dart';

/// Home: welcome, daily Bible verse, pledge summary, latest announcements and upcoming programs.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenTab});

  /// Switches the bottom navigation tab (1 = Giving, 3 = Church).
  final void Function(int index) onOpenTab;

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: const Text('Home'), actions: const [NotificationBell()]),
      body: RemoteView(
        load: () => api.get('dashboard'),
        builder: (context, data) {
          final member = Map<String, dynamic>.from(data['member'] as Map? ?? {});
          final verses = List<Map<String, dynamic>>.from(data['verses'] as List? ?? []);
          final pledges = Map<String, dynamic>.from(data['pledges'] as Map? ?? {});
          final announcements = List<Map<String, dynamic>>.from(data['announcements'] as List? ?? []);
          final programs = List<Map<String, dynamic>>.from(data['programs'] as List? ?? []);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _Welcome(member: member),
              if (verses.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final (i, v) in verses.indexed) _VerseCard(verse: v, featured: i == 0),
              ],
              SectionTitle('My pledges', trailing: TextButton(onPressed: () => onOpenTab(1), child: const Text('View'))),
              _PledgeSummary(pledges: pledges),
              SectionTitle('Announcements', trailing: TextButton(onPressed: () => onOpenTab(3), child: const Text('All'))),
              if (announcements.isEmpty) const EmptyNote(icon: Icons.notifications_none, text: 'No announcements right now.'),
              for (final a in announcements) _AnnouncementCard(announcement: a),
              const SectionTitle('Upcoming programs'),
              if (programs.isEmpty) const EmptyNote(icon: Icons.event_busy, text: 'No upcoming programs.'),
              for (final p in programs) _ProgramCard(program: p),
            ],
          );
        },
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.member});

  final Map<String, dynamic> member;

  @override
  Widget build(BuildContext context) {
    final firstName = asText(member['full_name'], 'Member').split(' ').first;
    Widget tag(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(20)),
          child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        );
    return BrandPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDate(DateTime.now().toIso8601String(), 'EEEE, d MMMM').toUpperCase(),
                  style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: .8),
                ),
                const SizedBox(height: 6),
                Text('Welcome back, $firstName', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    tag('Member No: ${asText(member['member_no'], '-')}'),
                    if (asText(member['pledge_no']).isNotEmpty) tag('Pledge No: ${member['pledge_no']}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Image.asset('assets/icons/logo.png', width: 46, height: 46, cacheWidth: 138),
          ),
        ],
      ),
    );
  }
}

class _VerseCard extends StatelessWidget {
  const _VerseCard({required this.verse, required this.featured});

  final Map<String, dynamic> verse;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final isToday = asText(verse['display_date']) == DateTime.now().toIso8601String().substring(0, 10);
    return Card(
      color: featured ? const Color(0xFFFFFBF1) : null,
      shape: featured
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: BorderSide(color: AppColors.gold.withValues(alpha: .45)),
            )
          : null,
      child: Padding(
        padding: EdgeInsets.all(featured ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (featured)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.auto_stories_outlined, color: AppColors.gold, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isToday ? 'VERSE OF THE DAY' : 'BIBLE VERSE',
                        style: const TextStyle(color: AppColors.goldText, fontWeight: FontWeight.w800, fontSize: 12.5, letterSpacing: 1),
                      ),
                    ),
                    Icon(Icons.format_quote_rounded, color: AppColors.gold.withValues(alpha: .6), size: 30),
                  ],
                ),
              ),
            Text(
              asText(verse['verse_text']),
              style: TextStyle(fontFamily: 'serif', fontSize: featured ? 18.5 : 16, fontStyle: FontStyle.italic, height: 1.55, color: const Color(0xFF2A2233)),
            ),
            const SizedBox(height: 12),
            Text(
              '— ${asText(verse['reference'])} (${asText(verse['translation'])})',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.purple, fontSize: 14.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _PledgeSummary extends StatelessWidget {
  const _PledgeSummary({required this.pledges});

  final Map<String, dynamic> pledges;

  @override
  Widget build(BuildContext context) {
    final pledged = asDouble(pledges['total_pledged']);
    final paid = asDouble(pledges['total_paid']);
    if (pledged <= 0) return const EmptyNote(icon: Icons.handshake_outlined, text: 'You have no pledges recorded.');
    final progress = (paid / pledged).clamp(0.0, 1.0);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(Icons.handshake_outlined),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paid so far', style: TextStyle(color: muted, fontSize: 13.5)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(ugx(paid), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
                      ),
                    ],
                  ),
                ),
                Pill('${(progress * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress, minHeight: 10, borderRadius: BorderRadius.circular(5)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _Figure(label: 'Pledged', value: ugx(pledged))),
                Container(width: 1, height: 36, color: AppColors.outline),
                const SizedBox(width: 16),
                Expanded(child: _Figure(label: 'Balance', value: ugx(pledges['balance']))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});

  final Map<String, dynamic> announcement;

  @override
  Widget build(BuildContext context) {
    final priority = asText(announcement['priority']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnnouncementIcon(priority),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(asText(announcement['title']), style: Theme.of(context).textTheme.titleMedium),
                      ?Pill.priority(priority),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    asText(announcement['message']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program});

  final Map<String, dynamic> program;

  @override
  Widget build(BuildContext context) {
    final p = program;
    final meta = [formatDate(p['program_date'], 'EEEE'), formatTime(p['start_time']), asText(p['venue'])].where((s) => s.isNotEmpty && s != '-').join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            DateBadge(p['program_date']),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asText(p['title']), style: Theme.of(context).textTheme.titleMedium),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(meta, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13.5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
