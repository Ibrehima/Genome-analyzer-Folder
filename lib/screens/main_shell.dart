import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'sequence_library_screen.dart';
import 'reports_screen.dart';
import 'assistant_screen.dart';
import '../utils/app_theme.dart';

/// App shell with adaptive navigation: a [NavigationRail] on desktop/tablet
/// widths (this app targets computer & tablet use first, per design
/// requirements) and a [BottomNavigationBar] fallback on narrow phone
/// widths.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    SequenceLibraryScreen(embedded: true),
    ReportsScreen(embedded: true),
    AssistantScreen(embedded: true),
  ];

  static const _destinations = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.dns_rounded, label: 'Library'),
    (icon: Icons.folder_copy_rounded, label: 'Reports'),
    (icon: Icons.auto_awesome, label: 'Assistant'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktopOrTablet = constraints.maxWidth >= 700;
        final isWideDesktop = constraints.maxWidth >= 1100;

        final body = IndexedStack(index: _index, children: _screens);

        if (!isDesktopOrTablet) {
          // Narrow / phone fallback layout.
          return Scaffold(
            body: body,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              items: _destinations
                  .map(
                    (d) => BottomNavigationBarItem(
                      icon: Icon(d.icon),
                      label: d.label,
                    ),
                  )
                  .toList(),
            ),
          );
        }

        // Desktop / tablet layout: persistent side NavigationRail.
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                extended: isWideDesktop,
                minExtendedWidth: 190,
                backgroundColor: AppColors.surface,
                labelType: isWideDesktop
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF00897B)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.biotech,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                destinations: _destinations
                    .map(
                      (d) => NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(
                          d.icon,
                          color: AppColors.primaryBlue,
                        ),
                        label: Text(d.label),
                      ),
                    )
                    .toList(),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}
