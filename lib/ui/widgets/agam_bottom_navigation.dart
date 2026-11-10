import 'package:flutter/material.dart';

/// Shared bottom navigation used by the Jelajah and Trail pages.
class AgamBottomNavigation extends StatelessWidget {
  const AgamBottomNavigation({
    required this.selectedIndex,
    required this.onSelect,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.explore_outlined, 'Jelajah'),
      (Icons.emoji_events_outlined, 'Trail'),
      (Icons.directions_walk_rounded, 'Cari & Rute'),
      (Icons.settings_outlined, 'Pengaturan'),
    ];

    return Container(
      height: 57,
      decoration: const BoxDecoration(
        color: Color(0xFFFBFAFF),
        border: Border(top: BorderSide(color: Color(0xFFE9E8F0))),
      ),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onSelect(index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      items[index].$1,
                      size: 18,
                      color: index == selectedIndex
                          ? const Color(0xFF073B82)
                          : const Color(0xFF454A57),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[index].$2,
                      style: TextStyle(
                        fontSize: 9,
                        color: index == selectedIndex
                            ? const Color(0xFF073B82)
                            : const Color(0xFF454A57),
                        fontWeight: index == selectedIndex
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
