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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // Scrollable so pull-to-refresh still works on an empty page.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(icon, size: 56, color: muted),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 15)),
        if (action != null) ...[const SizedBox(height: 20), Center(child: action)],
      ],
    );
  }
}

/// Small uppercase heading above a group of cards.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
