import 'package:flutter/material.dart';

import 'agam_motion.dart';
import 'agam_theme.dart';

/// Two destinations. Search lives on the map and settings behind the
/// account button in the header.
/// A tinted pill slides between tabs, so a switch reads as one movement.
class AgamBottomNavigation extends StatelessWidget {
  const AgamBottomNavigation({
    required this.selectedIndex,
    required this.onSelect,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.explore_outlined, Icons.explore_rounded, 'Jelajah'),
    (Icons.flag_outlined, Icons.flag_rounded, 'Trail'),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Color(0x0F0B1F44),
          blurRadius: 16,
          offset: Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth / _items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: AgamMotion.duration(context, 340),
                    curve: AgamMotion.drawer,
                    left: width * selectedIndex.clamp(0, _items.length - 1),
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AgamColors.tint,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var index = 0; index < _items.length; index++)
                        Expanded(
                          child: _NavItem(
                            icon: _items[index].$1,
                            selectedIcon: _items[index].$2,
                            label: _items[index].$3,
                            selected: index == selectedIndex,
                            onTap: () => onSelect(index),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AgamColors.brand : AgamColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      child: AgamPressFeedback(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: AgamMotion.duration(context, 180),
                switchInCurve: AgamMotion.easeOut,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: .85, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey(selected),
                  size: 23,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App bar shared by the three tabs: the AGAM logo and wordmark on the
/// left, the account button on the right that opens profile and settings.
class AgamAppHeader extends AppBar {
  AgamAppHeader({
    super.key,
    VoidCallback? onProfile,
    bool showProfile = true,
    Widget? status,
  }) : super(
         toolbarHeight: 64,
         backgroundColor: Colors.white,
         surfaceTintColor: Colors.transparent,
         elevation: 0,
         scrolledUnderElevation: 0,
         automaticallyImplyLeading: false,
         titleSpacing: 16,
         title: _AgamHeaderContents(
           status: status,
           onProfile: onProfile,
           showProfile: showProfile,
         ),
       );
}

class _AgamHeaderContents extends StatelessWidget {
  const _AgamHeaderContents({
    this.onProfile,
    this.showProfile = true,
    this.status,
  });

  final Widget? status;
  final VoidCallback? onProfile;
  final bool showProfile;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/media/logo.png',
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          cacheWidth: 108,
        ),
      ),
      const SizedBox(width: 10),
      // Only the wordmark shrinks; the logo, status and account button keep
      // their size on narrow phones.
      Expanded(
        child: Row(
          children: [
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AGAM',
                    maxLines: 1,
                    style: TextStyle(
                      color: AgamColors.ink,
                      fontSize: 17,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            if (status != null) ...[const SizedBox(width: 8), status!],
          ],
        ),
      ),
      const SizedBox(width: 8),
      if (showProfile)
        Tooltip(
          message: 'Profil & pengaturan',
          child: Semantics(
            button: true,
            label: 'Buka profil dan pengaturan',
            child: AgamPressFeedback(
              child: InkWell(
                onTap: onProfile,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AgamColors.cyan, AgamColors.brand],
                    ),
                  ),
                  child: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person_rounded,
                      color: AgamColors.brand,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
