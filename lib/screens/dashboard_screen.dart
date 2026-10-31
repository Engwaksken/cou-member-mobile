import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../widgets/remote_view.dart';
import 'home_shell.dart';

/// Home: welcome, daily Bible verse, pledge summary, latest announcements and upcoming programs.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenTab});

  /// Switches the bottom navigation tab (1 = Giving, 3 = Church).
  final void Function(int index) onOpenTab;

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: const Text('Home')),
      body: RemoteView(
        load: () => api.get('dashboard'),
        builder: (context, data) {
          final member = Map<String, dynamic>.from(data['member'] as Map? ?? {});
          final verses = List<Map<String, dynamic>>.from(data['verses'] as List? ?? []);
          final pledges = Map<String, dynamic>.from(data['pledges'] as Map? ?? {});
          final announcements = List<Map<String, dynamic>>.from(data['announcements'] as List? ?? []);
          final programs = List<Map<String, dynamic>>.from(data['programs'] as List? ?? []);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Welcome(member: member),
              if (verses.isNotEmpty) ...[
                const SectionTitle('Bible verse'),
                for (final (i, v) in verses.indexed) _VerseCard(verse: v, featured: i == 0),
              ],
              SectionTitle('My pledges', trailing: TextButton(onPressed: () => onOpenTab(1), child: const Text('View'))),
              _PledgeSummary(pledges: pledges),
              SectionTitle('Announcements', trailing: TextButton(onPressed: () => onOpenTab(3), child: const Text('All'))),
              if (announcements.isEmpty) const _Muted('No announcements right now.'),
              for (final a in announcements)
                Card(
                  child: ListTile(
                    leading: Icon(Icons.campaign, color: asText(a['priority']) == 'Urgent' ? Colors.red : Theme.of(context).colorScheme.primary),
                    title: Text(asText(a['title'])),
                    subtitle: Text(asText(a['message']), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),
              const SectionTitle('Upcoming programs'),
              if (programs.isEmpty) const _Muted('No upcoming programs.'),
              for (final p in programs)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(asText(p['title'])),
                    subtitle: Text([formatDate(p['program_date'], 'EEE d MMM'), formatTime(p['start_time']), asText(p['venue'])].where((s) => s.isNotEmpty).join(' · ')),
                  ),
                ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFF4A1E8F), Color(0xFF7B3FCF)]),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back, $firstName', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Member No: ${asText(member['member_no'], '-')}', style: const TextStyle(color: Colors.white70)),
                if (asText(member['pledge_no']).isNotEmpty) Text('Pledge No: ${member['pledge_no']}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Image.asset('assets/icons/logo.png', width: 48, height: 48, cacheWidth: 144),
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: featured ? scheme.primaryContainer.withValues(alpha: .45) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (featured)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  asText(verse['display_date']) == DateTime.now().toIso8601String().substring(0, 10) ? 'VERSE OF THE DAY' : 'BIBLE VERSE',
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            Text(asText(verse['verse_text']), style: TextStyle(fontSize: featured ? 17 : 15, fontStyle: FontStyle.italic, height: 1.5)),
            const SizedBox(height: 8),
            Text('${asText(verse['reference'])} (${asText(verse['translation'])})', style: const TextStyle(fontWeight: FontWeight.w600)),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: pledged <= 0
            ? const Text('You have no pledges recorded.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _Figure(label: 'Pledged', value: ugx(pledged))),
                      Expanded(child: _Figure(label: 'Paid', value: ugx(paid))),
                      Expanded(child: _Figure(label: 'Balance', value: ugx(pledges['balance']))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: (paid / pledged).clamp(0, 1), minHeight: 8, borderRadius: BorderRadius.circular(4)),
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
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}
