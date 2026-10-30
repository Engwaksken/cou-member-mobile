import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../widgets/remote_view.dart';
import 'home_shell.dart';

/// The member's own giving records: pledges, tithe, thanksgiving and contributions.
class GivingScreen extends StatelessWidget {
  const GivingScreen({super.key, this.initialTab = 0});

  /// Tab to show first, an index into [tabs].
  final int initialTab;

  /// Tabs in order; `type` is the API giving type ('pledges' has its own endpoint).
  static const tabs = [
    (type: 'pledges', label: 'Pledges', icon: Icons.handshake_outlined),
    (type: 'tithe', label: 'Tithe', icon: Icons.percent),
    (type: 'thanksgiving', label: 'Thanksgiving', icon: Icons.celebration_outlined),
    (type: 'contributions', label: 'Contributions', icon: Icons.savings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialTab.clamp(0, tabs.length - 1),
      child: Scaffold(
        appBar: AppBar(
          leading: const MenuButton(),
          title: const Text('My Giving'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in tabs) Tab(text: t.label)],
          ),
        ),
        body: TabBarView(
          children: [for (final t in tabs) t.type == 'pledges' ? const _PledgesTab() : _GivingTab(type: t.type, label: t.label)],
        ),
      ),
    );
  }
}

class _GivingTab extends StatelessWidget {
  const _GivingTab({required this.type, required this.label});

  final String type;
  final String label;

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return RemoteView(
      load: () => api.get('giving', {'type': type}),
      builder: (context, data) {
        final items = List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
        if (items.isEmpty) return MessageView(icon: Icons.receipt_long_outlined, message: 'No $label records yet.');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45),
              child: ListTile(
                title: Text('Total $label'),
                subtitle: Text('${items.length} record${items.length == 1 ? '' : 's'}'),
                trailing: Text(ugx(data['total']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            for (final item in items)
              Card(
                child: ListTile(
                  title: Text(asText(item['description'], label)),
                  subtitle: Text([formatDate(item['date']), asText(item['payment_method']), asText(item['reference'])].where((s) => s.isNotEmpty && s != '-').join(' · ')),
                  trailing: Text(ugx(item['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PledgesTab extends StatelessWidget {
  const _PledgesTab();

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return RemoteView(
      load: () => api.get('pledges'),
      builder: (context, data) {
        final items = List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
        if (items.isEmpty) return const MessageView(icon: Icons.handshake_outlined, message: 'You have no pledges recorded.');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [for (final p in items) _PledgeCard(pledge: p)],
        );
      },
    );
  }
}

class _PledgeCard extends StatelessWidget {
  const _PledgeCard({required this.pledge});

  final Map<String, dynamic> pledge;

  @override
  Widget build(BuildContext context) {
    final pledged = asDouble(pledge['amount_pledged']);
    final paid = asDouble(pledge['amount_paid']);
    final payments = List<Map<String, dynamic>>.from(pledge['payments'] as List? ?? []);
    final status = asText(pledge['status']);
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        title: Text(asText(pledge['purpose'], 'Pledge'), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${asText(pledge['pledge_no'])} · ${formatDate(pledge['pledge_date'])}${asText(pledge['due_date']).isNotEmpty ? ' · Due ${formatDate(pledge['due_date'])}' : ''}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: pledged > 0 ? (paid / pledged).clamp(0, 1) : 0, minHeight: 6, borderRadius: BorderRadius.circular(3)),
            const SizedBox(height: 6),
            Text('Paid ${ugx(paid)} of ${ugx(pledged)} · Balance ${ugx(pledge['balance'])}'),
          ],
        ),
        trailing: Chip(label: Text(status), visualDensity: VisualDensity.compact),
        children: [
          if (payments.isEmpty) const ListTile(dense: true, title: Text('No payments recorded yet.')),
          for (final pay in payments)
            ListTile(
              dense: true,
              leading: const Icon(Icons.payments_outlined),
              title: Text(ugx(pay['amount'])),
              subtitle: Text([formatDate(pay['paid_on']), asText(pay['method']), asText(pay['receipt_no'])].where((s) => s.isNotEmpty && s != '-').join(' · ')),
            ),
        ],
      ),
    );
  }
}
