import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Persistent bottom navigation wrapping the two main destinations
/// (Accueil, which is the map, / Favoris). Every other screen (search
/// results, station detail, explore lists...) is pushed on top and
/// intentionally covers it, like drilling into a section.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: 'Favoris',
          ),
        ],
      ),
    );
  }
}
