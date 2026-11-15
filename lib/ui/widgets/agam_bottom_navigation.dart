import 'package:flutter/material.dart';

/// Shared bottom navigation used by the Jelajah and Trail pages.
class AgamBottomNavigation extends StatelessWidget {
  const AgamBottomNavigation({
    required this.selectedIndex,
    required this.onSelect,
    this.internalDemo = false,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool internalDemo;

  @override
  Widget build(BuildContext context) {
    final List<(int, IconData, String)> items = internalDemo
        ? [
            (0, Icons.explore_outlined, 'Jelajah'),
            (2, Icons.search_rounded, 'Cari POI'),
          ]
        : [
            (0, Icons.explore_outlined, 'Jelajah'),
            (1, Icons.emoji_events_outlined, 'Trail'),
            (2, Icons.directions_walk_rounded, 'Cari & Rute'),
            (3, Icons.settings_outlined, 'Pengaturan'),
          ];

    return Container(
      height: 57,
      decoration: const BoxDecoration(
        color: Color(0xFFFBFAFF),
        border: Border(top: BorderSide(color: Color(0xFFE9E8F0))),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                onTap: () => onSelect(item.$1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.$2,
                      size: 18,
                      color: item.$1 == selectedIndex
                          ? const Color(0xFF073B82)
                          : const Color(0xFF454A57),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.$3,
                      style: TextStyle(
                        fontSize: 9,
                        color: item.$1 == selectedIndex
                            ? const Color(0xFF073B82)
                            : const Color(0xFF454A57),
                        fontWeight: item.$1 == selectedIndex
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AgamAppHeader extends AppBar {
  AgamAppHeader({super.key, VoidCallback? onProfile, bool showProfile = true})
    : super(
        toolbarHeight: 54,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: _AgamHeaderContents(
          onProfile: onProfile,
          showProfile: showProfile,
        ),
      );
}

class _AgamHeaderContents extends StatelessWidget {
  const _AgamHeaderContents({this.onProfile, this.showProfile = true});

  final VoidCallback? onProfile;
  final bool showProfile;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(
          'assets/media/logo.png',
          width: 32,
          height: 32,
          fit: BoxFit.cover,
        ),
      ),
      const Spacer(),
      if (showProfile)
        InkWell(
          onTap: onProfile,
          customBorder: const CircleBorder(),
          child: const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFE7E9F2),
            child: Icon(
              Icons.person_rounded,
              color: Color(0xFF50576A),
              size: 20,
            ),
          ),
        ),
    ],
  );
}
