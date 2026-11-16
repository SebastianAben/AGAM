import 'dart:async';

import 'package:flutter/material.dart';

import '../contracts/app_services.dart';
import '../logic/session/trigger_notifier.dart';
import 'widgets/agam_motion.dart';
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
  const AgamApp({
    super.key,
    this.services,
    this.poiViewRequests = const Stream.empty(),
    this.internalDemo = false,
    this.onPoiAction,
  });

  /// Services can be injected; otherwise device location and permission are real.
  final AppServices? services;
  final Stream<String> poiViewRequests;
  final bool internalDemo;
  final Future<void> Function(String, TriggerAction)? onPoiAction;

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
                builder: (_) => AgamMainShell(
                  services: _appServices,
                  poiViewRequests: widget.poiViewRequests,
                  internalDemo: widget.internalDemo,
                  onPoiAction: widget.onPoiAction,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AgamMainShell extends StatefulWidget {
  const AgamMainShell({
    super.key,
    required this.services,
    this.poiViewRequests = const Stream.empty(),
    this.internalDemo = false,
    this.onPoiAction,
  });

  final AppServices services;
  final Stream<String> poiViewRequests;
  final bool internalDemo;
  final Future<void> Function(String, TriggerAction)? onPoiAction;

  @override
  State<AgamMainShell> createState() => _AgamMainShellState();
}

class _AgamMainShellState extends State<AgamMainShell> {
  int _selectedIndex = 0;
  StreamSubscription<String>? _views;
  final _mapRequests = StreamController<String>.broadcast();

  @override
  void initState() {
    super.initState();
    _views = widget.poiViewRequests.listen((_) {
      if (mounted) setState(() => _selectedIndex = 0);
    });
  }

  @override
  void dispose() {
    unawaited(_views?.cancel());
    unawaited(_mapRequests.close());
    super.dispose();
  }

  void _selectTab(int index) {
    if (index >= 0 && index <= 3) {
      setState(() => _selectedIndex = index);
      return;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAF8FF),
    appBar: AgamAppHeader(
      status: widget.internalDemo ? const _DemoModeChip() : null,
      showProfile: _selectedIndex != 3,
      onProfile: () => _selectTab(3),
    ),
    body: Column(
      children: [
        Expanded(
          child: AgamTabTransition(
            index: _selectedIndex,
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                ExploreMapScreen(
                  services: widget.services,
                  embedded: true,
                  isActive: _selectedIndex == 0,
                  onTabSelected: _selectTab,
                  poiViewRequests: widget.poiViewRequests,
                  poiMapRequests: _mapRequests.stream,
                  onPoiAction: widget.onPoiAction,
                  onAutomaticPoi: () => _selectTab(0),
                  internalDemo: widget.internalDemo,
                ),
                OrientationTrailScreen(
                  services: widget.services,
                  embedded: true,
                  internalDemo: widget.internalDemo,
                  onTabSelected: _selectTab,
                ),
                SearchRouteScreen(
                  services: widget.services,
                  onShowPoiOnMap: (id) {
                    _selectTab(0);
                    _mapRequests.add(id);
                  },
                  internalDemo: widget.internalDemo,
                  onTabSelected: _selectTab,
                ),
                ProfilePreviewScreen(
                  services: widget.services,
                  internalDemo: widget.internalDemo,
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: AgamBottomNavigation(
            selectedIndex: _selectedIndex,
            onSelect: _selectTab,
            internalDemo: widget.internalDemo,
          ),
        ),
      ],
    ),
  );
}

class _DemoModeChip extends StatelessWidget {
  const _DemoModeChip();

  @override
  Widget build(BuildContext context) => const Text(
    'Mode uji',
    style: TextStyle(fontSize: 8, color: Color(0xFF596174)),
  );
}
