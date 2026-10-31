import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// Branded page for signed-out screens: a purple header with the crest, then a white sheet for the form.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, required this.subtitle, required this.child, this.compact = false, this.showBack = false});

  final String title;
  final String subtitle;
  final Widget child;
  final bool compact;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final logo = compact ? 56.0 : 80.0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: const BoxDecoration(gradient: AppColors.brandGradient),
                padding: EdgeInsets.fromLTRB(24, top + (showBack ? 4 : 28), 24, 48),
                child: Column(
                  children: [
                    if (showBack) const Align(alignment: Alignment.centerLeft, child: BackButton(color: Colors.white)),
                    Container(
                      padding: EdgeInsets.all(compact ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 24, offset: const Offset(0, 8))],
                      ),
                      child: Image.asset('assets/icons/logo.png', width: logo, height: logo, cacheHeight: (logo * 3).round(), semanticLabel: 'Church of Uganda logo'),
                    ),
                    SizedBox(height: compact ? 12 : 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 15)),
                    const SizedBox(height: 12),
                    Container(width: 40, height: 3, decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2))),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: child)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Purple gradient panel, used for the home greeting and giving totals.
class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
        boxShadow: [BoxShadow(color: AppColors.purple.withValues(alpha: .25), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child),
    );
  }
}

/// Icon on a soft tinted square, leading list items.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.background, this.size = 44});

  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background ?? scheme.primaryContainer.withValues(alpha: .6), borderRadius: BorderRadius.circular(size * .3)),
      child: Icon(icon, color: color ?? AppColors.purple, size: size * .52),
    );
  }
}

/// Megaphone badge for an announcement, red when urgent.
class AnnouncementIcon extends StatelessWidget {
  const AnnouncementIcon(this.priority, {super.key});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final urgent = priority == 'Urgent';
    return IconBadge(Icons.campaign_outlined, color: urgent ? scheme.error : null, background: urgent ? scheme.errorContainer : null);
  }
}

/// Day and month on a tinted tile, leading a program.
class DateBadge extends StatelessWidget {
  const DateBadge(this.date, {super.key});

  final Object? date;

  @override
  Widget build(BuildContext context) {
    final day = formatDate(date, 'd');
    if (day == '-') return const IconBadge(Icons.event_outlined, size: 52);
    return Container(
      constraints: const BoxConstraints(minWidth: 52, minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatDate(date, 'MMM').toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.goldText, letterSpacing: .6)),
          Text(day, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.goldText, height: 1.1)),
        ],
      ),
    );
  }
}

/// Small rounded label, for priorities and statuses.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color, this.textColor});

  final String label;
  final Color? color;
  final Color? textColor;

  /// Announcement priority; null for normal priority.
  static Pill? priority(String priority) => switch (priority) {
        '' || 'Normal' => null,
        'Urgent' => Pill(priority, color: const Color(0xFFFDE2E1), textColor: const Color(0xFFB3261E)),
        _ => Pill(priority, color: AppColors.goldSoft, textColor: AppColors.goldText),
      };

  /// Pledge status, green when settled and red when overdue or cancelled.
  static Pill status(String status) {
    final s = status.toLowerCase();
    if (['complet', 'fulfil', 'paid', 'clear'].any(s.contains)) return Pill(status, color: AppColors.successSoft, textColor: AppColors.success);
    if (['overdue', 'cancel', 'default'].any(s.contains)) return Pill(status, color: const Color(0xFFFDE2E1), textColor: const Color(0xFFB3261E));
    return Pill(status);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color ?? scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textColor ?? scheme.onPrimaryContainer)),
    );
  }
}

/// Quiet card for an empty section inside a longer page.
class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: muted),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: muted))),
          ],
        ),
      ),
    );
  }
}

/// Label above a value, for detail lists.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconBadge(icon, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
