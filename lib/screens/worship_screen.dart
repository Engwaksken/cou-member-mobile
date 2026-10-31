import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/remote_view.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';

/// Order of Service and Church of Uganda hymns.
class WorshipScreen extends StatelessWidget {
  const WorshipScreen({super.key, this.initialTab = 0});

  /// Tab to show first.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 2 - 1),
      child: Scaffold(
        appBar: AppBar(
          leading: const MenuButton(),
          title: const Text('Worship'),
          bottom: const TabBar(tabs: [Tab(text: 'Order of Service'), Tab(text: 'Hymns')]),
        ),
        body: const TabBarView(children: [OrderOfServiceView(), HymnsView()]),
      ),
    );
  }
}

class OrderOfServiceView extends StatefulWidget {
  const OrderOfServiceView({super.key});

  @override
  State<OrderOfServiceView> createState() => _OrderOfServiceViewState();
}

class _OrderOfServiceViewState extends State<OrderOfServiceView> {
  int? _selectedId;
  final _viewKey = GlobalKey<RemoteViewState>();

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return RemoteView(
      key: _viewKey,
      load: () => api.get('order_of_service', {if (_selectedId != null) 'id': '$_selectedId'}),
      builder: (context, data) {
        final orders = List<Map<String, dynamic>>.from(data['orders'] as List? ?? []);
        final order = data['order'] == null ? null : Map<String, dynamic>.from(data['order'] as Map);
        if (order == null) return const MessageView(icon: Icons.format_list_numbered, message: 'No order of service has been published yet.');
        final items = List<Map<String, dynamic>>.from(order['items'] as List? ?? []);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (orders.length > 1)
              DropdownButtonFormField<int>(
                initialValue: order['id'] as int,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Service', isDense: true),
                items: [
                  for (final o in orders)
                    DropdownMenuItem(value: o['id'] as int, child: Text('${formatDate(o['service_date'])} — ${asText(o['title'])}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (id) {
                  _selectedId = id;
                  _viewKey.currentState?.reload();
                },
              ),
            if (orders.length > 1) const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const IconBadge(Icons.church_outlined),
                        const SizedBox(width: 14),
                        Expanded(child: Text(asText(order['title']), style: Theme.of(context).textTheme.titleLarge)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      [formatDate(order['service_date'], 'EEEE, d MMM y'), formatTime(order['service_time']), asText(order['service_type'])].where((s) => s.isNotEmpty).join(' · '),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                    ),
                    if (asText(order['notes']).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(12)),
                        child: Text(asText(order['notes']), style: const TextStyle(color: AppColors.goldText)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty) const EmptyNote(icon: Icons.hourglass_empty, text: 'The items for this service have not been added yet.'),
            for (final (i, item) in items.indexed)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  title: Text(asText(item['item_title'])),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (asText(item['led_by']).isNotEmpty) Text('Led by ${item['led_by']}'),
                      if (asText(item['details']).isNotEmpty) Text(asText(item['details'])),
                      if (item['hymn_id'] != null)
                        TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                          icon: const Icon(Icons.music_note, size: 18),
                          label: Text('${asText(item['hymn_number']).isNotEmpty ? '#${item['hymn_number']} ' : ''}${asText(item['hymn_title'])}'),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HymnScreen(hymnId: item['hymn_id'] as int))),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class HymnsView extends StatefulWidget {
  const HymnsView({super.key});

  @override
  State<HymnsView> createState() => _HymnsViewState();
}

class _HymnsViewState extends State<HymnsView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return RemoteView(
      load: () => api.get('hymns'),
      builder: (context, data) {
        final all = List<Map<String, dynamic>>.from(data['items'] as List? ?? []);
        if (all.isEmpty) return const MessageView(icon: Icons.music_note_outlined, message: 'No hymns have been published yet.');
        final q = _query.toLowerCase();
        final items = q.isEmpty
            ? all
            : all.where((h) => [h['hymn_number'], h['title'], h['author'], h['hymn_book'], h['theme']].any((v) => asText(v).toLowerCase().contains(q))).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by number, title or author'),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty) const EmptyNote(icon: Icons.search_off, text: 'No hymns match your search.'),
            for (final h in items)
              Card(
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .6), borderRadius: BorderRadius.circular(14)),
                    child: Text(asText(h['hymn_number'], '♪'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.purple)),
                  ),
                  title: Text(asText(h['title'])),
                  subtitle: Text([asText(h['hymn_book']), asText(h['language']), asText(h['theme'])].where((s) => s.isNotEmpty).join(' · ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HymnScreen(hymnId: h['id'] as int))),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One hymn: details, study notes and lyrics (only when the church may reproduce them).
class HymnScreen extends StatelessWidget {
  const HymnScreen({super.key, required this.hymnId});

  final int hymnId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Hymn')),
      body: RemoteView(
        load: () => api.get('hymn', {'id': '$hymnId'}),
        builder: (context, data) {
          final h = Map<String, dynamic>.from(data['hymn'] as Map);
          final details = {
            'Hymn book': h['hymn_book'],
            'Language': h['language'],
            'Author / Translator': h['author'],
            'Tune / Metre': h['tune'],
            'Theme / Season': h['theme'],
            'Scripture': h['scripture_reference'],
          }..removeWhere((_, v) => asText(v).isEmpty);
          final muted = Theme.of(context).colorScheme.onSurfaceVariant;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              BrandPanel(
                child: Row(
                  children: [
                    if (asText(h['hymn_number']).isNotEmpty) ...[
                      Container(
                        constraints: const BoxConstraints(minWidth: 56),
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(16)),
                        child: Text('#${h['hymn_number']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold)),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(child: Text(asText(h['title']), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.25))),
                  ],
                ),
              ),
              if (details.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in details.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Text.rich(TextSpan(children: [
                              TextSpan(text: '${e.key}: ', style: TextStyle(color: muted)),
                              TextSpan(text: asText(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ])),
                          ),
                      ],
                    ),
                  ),
                ),
              if (asText(h['study_notes']).isNotEmpty) ...[
                const SectionTitle('Study notes'),
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(asText(h['study_notes']), style: const TextStyle(height: 1.55)))),
              ],
              if (asText(h['lyrics']).isNotEmpty) ...[
                const SectionTitle('Lyrics'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SelectableText(asText(h['lyrics']), style: const TextStyle(fontFamily: 'serif', fontSize: 18, height: 1.7)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  [asText(h['copyright_status']), asText(h['copyright_notice'])].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
