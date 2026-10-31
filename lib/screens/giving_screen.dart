import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/remote_view.dart';
import '../widgets/ui.dart';
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
          children: [for (final t in tabs) t.type == 'pledges' ? const _PledgesTab() : _GivingTab(type: t.type, label: t.label, icon: t.icon)],
        ),
      ),
    );
  }
}

class _GivingTab extends StatelessWidget {
  const _GivingTab({required this.type, required this.label, required this.icon});

  final String type;
  final String label;
  final IconData icon;

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
            BrandPanel(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total $label', style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 14.5)),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(ugx(data['total']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 26)),
                        ),
                        const SizedBox(height: 4),
                        Text('${items.length} record${items.length == 1 ? '' : 's'}', style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 13.5)),
                      ],
                    ),
                  ),
                  Icon(icon, color: AppColors.gold, size: 40),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Card(
                child: ListTile(
                  leading: IconBadge(icon),
                  title: Text(asText(item['description'], label)),
                  subtitle: Text([formatDate(item['date']), asText(item['payment_method']), asText(item['reference'])].where((s) => s.isNotEmpty && s != '-').join(' · ')),
                  trailing: Text(ugx(item['amount']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.purple)),
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(asText(pledge['purpose'], 'Pledge'), style: Theme.of(context).textTheme.titleMedium),
            if (status.isNotEmpty) Pill.status(status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${asText(pledge['pledge_no'])} · ${formatDate(pledge['pledge_date'])}${asText(pledge['due_date']).isNotEmpty ? ' · Due ${formatDate(pledge['due_date'])}' : ''}',
              style: TextStyle(color: muted, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: pledged > 0 ? (paid / pledged).clamp(0, 1) : 0, minHeight: 8, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'Paid ${ugx(paid)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.purple)),
                  TextSpan(text: ' of ${ugx(pledged)}'),
                ])),
                Text('Balance ${ugx(pledge['balance'])}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        children: [
          const Divider(indent: 16, endIndent: 16),
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
