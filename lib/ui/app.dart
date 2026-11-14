import 'package:flutter/material.dart';

import '../contracts/app_services.dart';
import 'explore_map_screen.dart';
import 'onboarding_screen.dart';
import 'orientation_trail_screen.dart';
import 'profile_preview_screen.dart';
import 'search_route_screen.dart';
import 'device_app_services.dart';
import 'widgets/agam_bottom_navigation.dart';
import 'widgets/agam_scroll_behavior.dart';

/// Root widget AGAM.
class AgamApp extends StatefulWidget {
  const AgamApp({super.key, this.services});

  /// Services can be injected; otherwise device location and permission are real.
  final AppServices? services;

  @override
  State<AgamApp> createState() => _AgamAppState();
}

class _AgamAppState extends State<AgamApp> {
  late AppServices _appServices;

  @override
  void initState() {
    super.initState();
    _appServices = widget.services ?? createDeviceAppServices();
  }

  @override
  void didUpdateWidget(covariant AgamApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.services != widget.services && widget.services != null) {
      _appServices = widget.services!;
    }
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF124DA5);

    return MaterialApp(
      title: 'AGAM',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AgamScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAF8FF),
        colorScheme: ColorScheme.fromSeed(seedColor: navy),
        fontFamily: 'PlusJakartaSans',
      ),
      home: Builder(
        builder: (context) => OnboardingScreen(
          permissions: _appServices.permissions,
          onAccessGranted: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => AgamMainShell(services: _appServices),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AgamMainShell extends StatefulWidget {
  const AgamMainShell({super.key, required this.services});

  final AppServices services;

  @override
  State<AgamMainShell> createState() => _AgamMainShellState();
}

class _AgamMainShellState extends State<AgamMainShell> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    if (index >= 0 && index <= 3) {
      setState(() => _selectedIndex = index);
      return;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAF8FF),
    appBar: AgamAppHeader(showProfile: _selectedIndex != 3),
    body: Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              ExploreMapScreen(
                services: widget.services,
                embedded: true,
                isActive: _selectedIndex == 0,
                onTabSelected: _selectTab,
              ),
              OrientationTrailScreen(
                services: widget.services,
                embedded: true,
                onTabSelected: _selectTab,
              ),
              SearchRouteScreen(
                services: widget.services,
                onTabSelected: _selectTab,
              ),
              const ProfilePreviewScreen(),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: AgamBottomNavigation(
            selectedIndex: _selectedIndex,
            onSelect: _selectTab,
          ),
        ),
      ],
    ),
  );
}
