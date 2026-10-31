import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'church_screen.dart';
import 'dashboard_screen.dart';
import 'edit_profile_screen.dart';
import 'giving_screen.dart';
import 'profile_screen.dart';
import 'worship_screen.dart';

/// Main app with bottom navigation and a side menu. Tabs are created on first visit and then kept alive.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Opens the side menu from any screen inside the shell.
  static void openMenu(BuildContext context) => context.findAncestorStateOfType<_HomeShellState>()?._scaffold.currentState?.openDrawer();

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  int _index = 0;
  final _visited = <int>{0};

  /// Inner tab to open per section, and a counter that rebuilds the section when the menu asks for another tab.
  final _initialTabs = <int, int>{};
  final _versions = <int, int>{};

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.volunteer_activism_outlined), selectedIcon: Icon(Icons.volunteer_activism), label: 'Giving'),
    NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Worship'),
    NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Church'),
    NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
  ];

  Widget _page(int i) {
    final key = ValueKey('$i-${_versions[i] ?? 0}');
    final tab = _initialTabs[i] ?? 0;
    return switch (i) {
      0 => DashboardScreen(key: key, onOpenTab: _select),
      1 => GivingScreen(key: key, initialTab: tab),
      2 => WorshipScreen(key: key, initialTab: tab),
      3 => ChurchScreen(key: key, initialTab: tab),
      _ => ProfileScreen(key: key),
    };
  }

  void _select(int i) => setState(() {
        _index = i;
        _visited.add(i);
      });

  /// Closes the menu and shows section [i], on inner [tab] when given.
  void _open(int i, [int? tab]) {
    _scaffold.currentState?.closeDrawer();
    setState(() {
      if (tab != null && (_initialTabs[i] ?? 0) != tab) {
        _initialTabs[i] = tab;
        _versions[i] = (_versions[i] ?? 0) + 1;
      }
      _index = i;
      _visited.add(i);
    });
  }

  /// Closes the menu, then runs [action] with the shell's context (the menu's own context goes away when it closes).
  void _run(void Function(BuildContext context) action) {
    _scaffold.currentState?.closeDrawer();
    action(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffold,
      drawer: _Menu(open: _open, run: _run, selected: _index),
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < _destinations.length; i++) _visited.contains(i) ? _page(i) : const SizedBox.shrink()],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.outline))),
        child: NavigationBar(selectedIndex: _index, onDestinationSelected: _select, destinations: _destinations),
      ),
    );
  }
}

/// Menu button for the app bar of each main screen.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: const Icon(Icons.menu), tooltip: 'Menu', onPressed: () => HomeShell.openMenu(context));
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.open, required this.run, required this.selected});

  final void Function(int section, [int? tab]) open;
  final void Function(void Function(BuildContext context) action) run;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<Session>().member;
    final name = asText(m['full_name'], 'Member');
    final photo = asText(m['photo_url']);
    final scheme = Theme.of(context).colorScheme;

    Widget tile(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1), child: child);
    Widget item(IconData icon, String label, int section, [int? tab]) => tile(ListTile(
          leading: Icon(icon),
          title: Text(label),
          selected: tab == null && selected == section,
          dense: tab != null,
          contentPadding: EdgeInsets.only(left: tab == null ? 16 : 24, right: 16),
          onTap: () => open(section, tab),
        ));
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 16, 6),
          child: Text(text.toUpperCase(), style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 1)),
        );

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.brandGradient),
            padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 24, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        foregroundImage: photo.isEmpty ? null : NetworkImage(photo),
                        child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.purple)),
                      ),
                    ),
                    const Spacer(),
                    Image.asset('assets/icons/logo.png', width: 44, height: 44, cacheWidth: 132, opacity: const AlwaysStoppedAnimation(.9)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 2),
                Text('${AppConfig.churchName} · ${asText(m['member_no'])}', style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 13.5)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          item(Icons.home_outlined, 'Home', 0),
          heading('Giving'),
          for (final (i, t) in GivingScreen.tabs.indexed) item(t.icon, t.label, 1, i),
          heading('Worship'),
          item(Icons.list_alt_outlined, 'Order of Service', 2, 0),
          item(Icons.library_music_outlined, 'Hymns', 2, 1),
          heading('Church'),
          item(Icons.campaign_outlined, 'Announcements', 3, 0),
          item(Icons.event_outlined, 'Programs', 3, 1),
          item(Icons.health_and_safety_outlined, 'Health Tips', 3, 2),
          item(Icons.school_outlined, 'Education Tips', 3, 3),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10), child: Divider()),
          item(Icons.person_outline, 'My Profile', 4),
          tile(ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit profile'),
            onTap: () => run((context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()))),
          )),
          tile(ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Change password'),
            onTap: () => run((context) => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
          )),
          tile(ListTile(
            leading: Icon(Icons.logout, color: scheme.error),
            title: Text('Sign out', style: TextStyle(color: scheme.error)),
            onTap: () => run((context) => confirmSignOut(context, context.read<Session>())),
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
