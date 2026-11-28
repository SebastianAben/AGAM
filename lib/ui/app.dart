import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../contracts/app_services.dart';
import '../contracts/models/account.dart';
import '../contracts/models/content.dart';
import '../contracts/models/location.dart';
import '../contracts/models/navigation.dart';
import 'walking_navigation_screen.dart';
import '../logic/session/trigger_notifier.dart';
import 'widgets/agam_motion.dart';
import 'explore_map_screen.dart';
import 'onboarding_screen.dart';
import 'orientation_trail_screen.dart';
import 'profile_preview_screen.dart';
import 'search_route_screen.dart';
import 'auth_screen.dart';
import 'splash_screen.dart';
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
    this.poiDismissed = const Stream.empty(),
    this.onPoiAction,
  });

  /// Services can be injected; otherwise device location and permission are real.
  final AppServices? services;
  final Stream<String> poiViewRequests;

  /// POI ids the user skipped from the notification ("Lewati"), so their
  /// card does not come back when the app returns to the foreground.
  final Stream<String> poiDismissed;
  final Future<void> Function(String, TriggerAction)? onPoiAction;

  @override
  State<AgamApp> createState() => _AgamAppState();
}

class _AgamAppState extends State<AgamApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late AppServices _appServices;
  late AuthState _authState;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _appServices = widget.services ?? createDeviceAppServices();
    _watchAuth();
  }

  @override
  void didUpdateWidget(covariant AgamApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.services != widget.services && widget.services != null) {
      _appServices = widget.services!;
      _watchAuth();
    }
  }

  void _watchAuth() {
    unawaited(_authSubscription?.cancel());
    _authState = _appServices.auth.current;
    _authSubscription = _appServices.auth.state.listen((state) {
      final wasSignedIn = _authState.isSignedIn;
      final changed =
          wasSignedIn != state.isSignedIn ||
          _authState.account?.uid != state.account?.uid ||
          _authState.account?.email != state.account?.email ||
          _authState.account?.role != state.account?.role;
      if (wasSignedIn && !state.isSignedIn) {
        // Ensures any pushed screen (profile, detail, search, navigation) is
        // dismissed when the account signs out from anywhere (PRD §6).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        });
      }
      if (changed && mounted) {
        setState(() => _authState = state);
      } else {
        _authState = state;
      }
    });
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'AGAM',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AgamScrollBehavior(),
      theme: agamTheme(),
      home: SplashScreen(
        child: !_authState.isSignedIn
            ? AuthScreen(auth: _appServices.auth)
            // Kept inside the gate (not pushed as a replacement route) so
            // signing out always returns to UI10. Keyed by account so
            // switching accounts resets UI state cleanly.
            : _SignedInFlow(
                key: ValueKey(_authState.account?.uid),
                services: _appServices,
                poiViewRequests: widget.poiViewRequests,
                poiDismissed: widget.poiDismissed,
                onPoiAction: widget.onPoiAction,
              ),
      ),
    );
  }
}

/// Onboarding (when location permission is not yet granted), then the main
/// shell, for a signed-in account. Both live in the auth gate's place in the
/// tree instead of replacing its route.
class _SignedInFlow extends StatefulWidget {
  const _SignedInFlow({
    super.key,
    required this.services,
    required this.poiViewRequests,
    this.poiDismissed = const Stream.empty(),
    required this.onPoiAction,
  });

  final AppServices services;
  final Stream<String> poiViewRequests;
  final Stream<String> poiDismissed;
  final Future<void> Function(String, TriggerAction)? onPoiAction;

  @override
  State<_SignedInFlow> createState() => _SignedInFlowState();
}

class _SignedInFlowState extends State<_SignedInFlow> {
  bool? _ready;

  @override
  void initState() {
    super.initState();
    unawaited(_checkAccess());
  }

  Future<void> _checkAccess() async {
    final status = await widget.services.permissions.locationStatus();
    if (!mounted) return;
    setState(() => _ready = status == LocationPermissionStatus.granted);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready;
    if (ready == null) {
      return const ColoredBox(color: AgamColors.brandDeep);
    }
    return AnimatedSwitcher(
      duration: AgamMotion.duration(context, 320),
      switchInCurve: AgamMotion.easeOut,
      switchOutCurve: AgamMotion.easeOut,
      // Full-screen pages: keep tight constraints during the crossfade, as
      // a route would.
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: ready
          ? AgamMainShell(
              key: const ValueKey('shell'),
              services: widget.services,
              poiViewRequests: widget.poiViewRequests,
              poiDismissed: widget.poiDismissed,
              onPoiAction: widget.onPoiAction,
            )
          : OnboardingScreen(
              key: const ValueKey('onboarding'),
              permissions: widget.services.permissions,
              onAccessGranted: () => setState(() => _ready = true),
            ),
    );
  }
}

class AgamMainShell extends StatefulWidget {
  const AgamMainShell({
    super.key,
    required this.services,
    this.poiViewRequests = const Stream.empty(),
    this.poiDismissed = const Stream.empty(),
    this.onPoiAction,
  });

  final AppServices services;
  final Stream<String> poiViewRequests;
  final Stream<String> poiDismissed;
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
    // A notification "Lihat" lands on Jelajah with nothing stacked over
    // it: profile, search or an older detail close first, so the requested
    // POI detail opens straight over the map. This runs before the map's
    // own listener, which looks the POI up asynchronously and then pushes.
    // A screen that refuses to close (active walking guidance, whose brief
    // notification opens the POI too) is kept: popUntil would bypass its
    // PopScope and leave navigation running without its screen.
    _views = widget.poiViewRequests.listen((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil(
        (route) =>
            route.isFirst ||
            (route is ModalRoute &&
                route.popDisposition == RoutePopDisposition.doNotPop),
      );
      setState(() => _selectedIndex = 0);
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
            onShowPoiOnMap: (id) {
              Navigator.of(searchContext).pop();
              _selectTab(0);
              _mapRequests.add(id);
            },
          ),
        ),
      );

  /// Rute anywhere on Jelajah (the POI card, its detail, a recommendation)
  /// opens the route preview straight away, without the search page.
  Future<void> _openRoute(Poi poi) => WalkingNavigationScreen.open(
    context,
    services: widget.services,
    target: NavigationTarget.poi(poi),
  );

  Future<void> _openProfile() => Navigator.of(context).push<void>(
    AgamMotion.route((_) => ProfilePreviewScreen(services: widget.services)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AgamColors.canvas,
    appBar: AgamAppHeader(onProfile: _openProfile),
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
                  poiDismissed: widget.poiDismissed,
                  poiMapRequests: _mapRequests.stream,
                  onPoiAction: widget.onPoiAction,
                  onAutomaticPoi: () => _selectTab(0),
                  onOpenSearch: _openSearch,
                  onRoute: _openRoute,
                  onStartRoute: _openRoute,
                ),
                OrientationTrailScreen(
                  services: widget.services,
                  embedded: true,
                  isActive: _selectedIndex == 1,
                  onTabSelected: _selectTab,
                ),
              ],
            ),
          ),
        ),
        AgamBottomNavigation(
          selectedIndex: _selectedIndex,
          onSelect: _selectTab,
        ),
      ],
    ),
  );
}
