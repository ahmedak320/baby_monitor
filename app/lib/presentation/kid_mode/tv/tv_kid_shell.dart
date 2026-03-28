import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme/kid_theme.dart';
import 'dpad_handler.dart';
import 'tv_home_content.dart';
import '../screens/shorts_feed_screen.dart';
import '../screens/kid_library_screen.dart';
import '../screens/kid_profile_screen.dart';
import '../screens/kid_search_screen.dart';

/// TV shell: replaces KidHomeScreen on TV with a left-side navigation rail.
class TvKidShell extends ConsumerStatefulWidget {
  const TvKidShell({super.key});

  @override
  ConsumerState<TvKidShell> createState() => _TvKidShellState();
}

class _TvKidShellState extends ConsumerState<TvKidShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text('Home'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.short_text_outlined),
      selectedIcon: Icon(Icons.short_text),
      label: Text('Shorts'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search),
      label: Text('Search'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.video_library_outlined),
      selectedIcon: Icon(Icons.video_library),
      label: Text('Library'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.account_circle_outlined),
      selectedIcon: Icon(Icons.account_circle),
      label: Text('You'),
    ),
  ];

  Widget _buildContent() => switch (_selectedIndex) {
        0 => const TvHomeContent(),
        1 => const ShortsFeedScreen(),
        2 => const KidSearchScreen(),
        3 => const KidLibraryScreen(),
        4 => const KidProfileScreen(),
        _ => const TvHomeContent(),
      };

  @override
  Widget build(BuildContext context) {
    return DpadHandler(
      child: Theme(
        data: KidTheme.theme,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(48), // TV overscan safe area
            child: Row(
              children: [
                // Left navigation rail
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: KidTheme.background,
                  selectedIconTheme: const IconThemeData(
                    color: KidTheme.youtubeRed,
                    size: 28,
                  ),
                  unselectedIconTheme: const IconThemeData(
                    color: KidTheme.textSecondary,
                    size: 24,
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: KidTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: KidTheme.textSecondary,
                    fontSize: 12,
                  ),
                  destinations: _destinations,
                ),
                const VerticalDivider(
                  width: 1,
                  color: Color(0xFF383838),
                ),
                // Main content area
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
