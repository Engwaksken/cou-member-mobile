import 'package:flutter/material.dart';

import 'church_screen.dart';
import 'dashboard_screen.dart';
import 'giving_screen.dart';
import 'profile_screen.dart';
import 'worship_screen.dart';

/// Main app with bottom navigation. Tabs are created on first visit and then kept alive.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _visited = <int>{0};

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.volunteer_activism_outlined), selectedIcon: Icon(Icons.volunteer_activism), label: 'Giving'),
    NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Worship'),
    NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: 'Church'),
    NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
  ];

  Widget _page(int i) => switch (i) {
        0 => DashboardScreen(onOpenTab: _select),
        1 => const GivingScreen(),
        2 => const WorshipScreen(),
        3 => const ChurchScreen(),
        _ => const ProfileScreen(),
      };

  void _select(int i) => setState(() {
        _index = i;
        _visited.add(i);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < _destinations.length; i++) _visited.contains(i) ? _page(i) : const SizedBox.shrink()],
      ),
      bottomNavigationBar: NavigationBar(selectedIndex: _index, onDestinationSelected: _select, destinations: _destinations),
    );
  }
}
