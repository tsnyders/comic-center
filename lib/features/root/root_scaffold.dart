import 'package:flutter/cupertino.dart';

import '../../core/theme/app_colors.dart';
import '../browse/browse_screen.dart';
import '../downloads/downloads_screen.dart';
import '../library/library_screen.dart';
import '../settings/settings_screen.dart';

class RootScaffold extends StatelessWidget {
  const RootScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: AppColors.tabBarBackground,
        activeColor: AppColors.accent,
        inactiveColor: AppColors.textTertiary,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.book),
            activeIcon: Icon(CupertinoIcons.book_fill),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.globe),
            activeIcon: Icon(CupertinoIcons.globe),
            label: 'Browse',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.arrow_down_circle),
            activeIcon: Icon(CupertinoIcons.arrow_down_circle_fill),
            label: 'Downloads',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            activeIcon: Icon(CupertinoIcons.settings_solid),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) => switch (index) {
            0 => const LibraryScreen(),
            1 => const BrowseScreen(),
            2 => const DownloadsScreen(),
            3 => const SettingsScreen(),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}
