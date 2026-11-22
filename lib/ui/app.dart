import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../contracts/app_services.dart';
import '../contracts/models/content.dart';
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
import 'widgets/agam_theme.dart';

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
    return MaterialApp(
      title: 'AGAM',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AgamScrollBehavior(),
      theme: agamTheme(),
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
    if (index < 0 || index > 1) return;
    if (index != _selectedIndex) HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  /// Search opens over the map, like Google Maps; "Tampilkan di peta"
  /// closes it and focuses the chosen building on the Jelajah map.
  Future<void> _openSearch(FacilityCategory? facility) =>
      Navigator.of(context).push<void>(
        AgamMotion.route(
          (searchContext) => SearchRouteScreen(
            services: widget.services,
            initialFacility: facility,
            autofocus: facility == null,
            internalDemo: widget.internalDemo,
            onShowPoiOnMap: (id) {
              Navigator.of(searchContext).pop();
              _selectTab(0);
              _mapRequests.add(id);
            },
          ),
        ),
      );

  Future<void> _openProfile() => Navigator.of(context).push<void>(
    AgamMotion.route(
      (_) => ProfilePreviewScreen(
        services: widget.services,
        internalDemo: widget.internalDemo,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AgamColors.canvas,
    appBar: AgamAppHeader(
      status: widget.internalDemo ? const _DemoModeChip() : null,
      onProfile: _openProfile,
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
                  onOpenSearch: _openSearch,
                  internalDemo: widget.internalDemo,
                ),
                OrientationTrailScreen(
                  services: widget.services,
                  embedded: true,
                  isActive: _selectedIndex == 1,
                  internalDemo: widget.internalDemo,
                  onTabSelected: _selectTab,
                ),
              ],
            ),
          ),
        ),
        AgamBottomNavigation(
          selectedIndex: _selectedIndex,
          onSelect: _selectTab,
          internalDemo: widget.internalDemo,
        ),
      ],
    ),
  );
}

class _DemoModeChip extends StatelessWidget {
  const _DemoModeChip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AgamColors.warning.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      'Mode uji',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AgamColors.warning,
      ),
    ),
  );
}
