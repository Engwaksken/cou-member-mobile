import 'package:flutter/material.dart';

import '../core/api_client.dart';

/// Loads data from the API and shows it, with a spinner, an error with Retry, and pull-to-refresh.
/// [builder] must return a scrollable widget (for example a ListView) so pull-to-refresh works.
class RemoteView extends StatefulWidget {
  const RemoteView({super.key, required this.load, required this.builder});

  final Future<Map<String, dynamic>> Function() load;
  final Widget Function(BuildContext context, Map<String, dynamic> data) builder;

  @override
  State<RemoteView> createState() => RemoteViewState();
}

class RemoteViewState extends State<RemoteView> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load this page.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) {
      return MessageView(
        icon: Icons.cloud_off_outlined,
        message: _error ?? 'Could not load this page.',
        action: FilledButton.icon(onPressed: reload, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      );
    }
    return RefreshIndicator(
      onRefresh: reload,
      child: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [TextButton(onPressed: reload, child: const Text('Retry'))],
            ),
          Expanded(child: widget.builder(context, _data!)),
        ],
      ),
    );
  }
}

/// Centered icon and message, used for empty lists and errors.
class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Scrollable so pull-to-refresh still works on an empty page.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: .55), shape: BoxShape.circle),
            child: Icon(icon, size: 44, color: scheme.primary),
          ),
        ),
        const SizedBox(height: 20),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16, height: 1.4)),
        if (action != null) ...[const SizedBox(height: 24), Center(child: action)],
      ],
    );
  }
}

/// Heading above a group of cards, with an optional action on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, 22, 0, trailing == null ? 8 : 2),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w700))),
          ?trailing,
        ],
      ),
    );
  }
}
