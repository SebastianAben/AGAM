import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../contracts/contracts.dart';
import '../logic/routing/route_planner.dart';
import 'poi_detail_screen.dart';
import 'widgets/agam_components.dart';
import 'widgets/agam_motion.dart';
import 'widgets/agam_theme.dart';
import 'widgets/arrival_card.dart';
import 'widgets/offline_campus_map.dart';
import 'widgets/recommendation_card.dart';

/// Why the preview has no route to show yet (PRD §9.3, §11).
enum RouteProblem { locating, outsideCampus, offNetwork, unavailable }

/// UI06 with its preview: one map from the route summary to the walk itself.
///
/// The screen opens as a preview. The route is planned on the device with
/// [planWalkingRoute] and no session runs until "Mulai rute"; then the same
/// map flies to the user, the instruction panel comes down from the top and
/// the summary card turns into the trip status. On arrival the card becomes
/// UI07. Ending the route returns to wherever the screen was opened from.
///
/// The position is read only while this screen is shown and is kept in
/// memory; it is never stored, logged or sent (rules §5.1).
class WalkingNavigationScreen extends StatefulWidget {
  const WalkingNavigationScreen({
    super.key,
    required this.services,
    required this.target,
    this.start,
    this.end,
    this.trail = false,
  });

  final AppServices services;
  final NavigationTarget target;

  /// Starts the session and navigation on "Mulai rute". Defaults to a
  /// navigation session to [target]; Trail starts its own mode instead.
  final Future<void> Function()? start;

  /// Ends the route. Defaults to stopping navigation and ending the session.
  final Future<void> Function()? end;

  /// Trail picks its next stop itself after a check-in, so arrival only
  /// closes this screen and offers no recommendations of its own.
  final bool trail;

  static const startLabel = 'Mulai rute';
  static const retryLabel = 'Coba lagi';
  static const planningMessage = 'Menghitung rute…';
  static const passageNote =
      'Rute ini lewat lorong dalam gedung yang belum diverifikasi.';

  static String problemMessage(RouteProblem problem) => switch (problem) {
    RouteProblem.locating =>
      'Posisi Anda belum terbaca. Pastikan GPS menyala; rute muncul begitu '
          'posisi didapat.',
    RouteProblem.outsideCampus =>
      'Anda berada di luar area Kampus Ganesha. Rute muncul saat Anda sudah '
          'di dalam kampus.',
    RouteProblem.offNetwork =>
      'Anda terlalu jauh dari jalur pejalan kaki. Dekati jalan di kampus, '
          'lalu coba lagi.',
    RouteProblem.unavailable => 'Rute belum tersedia untuk tujuan ini.',
  };

  /// Opens the preview over the current page.
  static Future<void> open(
    BuildContext context, {
    required AppServices services,
    required NavigationTarget target,
    Future<void> Function()? start,
    Future<void> Function()? end,
    bool trail = false,
  }) => Navigator.of(context).push<void>(
    AgamMotion.mapRoute(
      (_) => WalkingNavigationScreen(
        services: services,
        target: target,
        start: start,
        end: end,
        trail: trail,
      ),
    ),
  );

  @override
  State<WalkingNavigationScreen> createState() =>
      _WalkingNavigationScreenState();
}

enum _Phase { preview, active }

class _WalkingNavigationScreenState extends State<WalkingNavigationScreen> {
  static const _activeStatuses = {
    NavigationStatus.calculating,
    NavigationStatus.onRoute,
    NavigationStatus.offRoute,
    NavigationStatus.rerouting,
    NavigationStatus.arrived,
  };

  final _map = GlobalKey<OfflineCampusMapState>();
  final _mapWindow = GlobalKey();
  late NavigationTarget _target = widget.target;
  late _Phase _phase;
  late NavigationState _navigation;
  LocationFix? _fix;
  List<Poi> _pois = const [];
  bool _poisLoaded = false;
  bool _mapReady = false;

  WalkingRoute? _plan;
  GeoPoint? _plannedFrom;
  RouteProblem? _problem;
  bool _planning = false;
  int _planRequest = 0;

  bool _starting = false;
  bool _ending = false;
  bool _closed = false;
  RecommendationView? _recommendation;
  int _recommendRequest = 0;

  StreamSubscription<LocationFix>? _positions;
  StreamSubscription<NavigationState>? _navigationStates;
  StreamSubscription<List<Poi>>? _poiStream;

  AppServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    _navigation = _services.navigation.current;
    _phase =
        _navigation.target?.id == _target.id &&
            _activeStatuses.contains(_navigation.status)
        ? _Phase.active
        : _Phase.preview;
    _fix = _services.location.lastFix;
    _positions = _services.location.positions.listen(_onFix);
    _navigationStates = _services.navigation.state.listen(_onNavigation);
    _poiStream = _services.pois.watchPois().listen((pois) {
      if (!mounted) return;
      final first = !_poisLoaded;
      _pois = pois;
      _poisLoaded = true;
      if (first && _phase == _Phase.preview) _replan();
    });
    if (_phase == _Phase.preview) {
      _replan();
    } else if (_navigation.status == NavigationStatus.arrived) {
      _recommendAfter(_navigation.target);
    }
  }

  @override
  void dispose() {
    _positions?.cancel();
    _navigationStates?.cancel();
    _poiStream?.cancel();
    super.dispose();
  }

  // ---- Preview ----

  void _onFix(LocationFix fix) {
    if (!mounted) return;
    setState(() => _fix = fix);
    if (_phase != _Phase.preview || _planning || _starting) return;
    final from = _plannedFrom;
    final moved =
        from == null || from.distanceTo(fix.position) > kRerouteDistanceM;
    // Plan on the first usable fix, and again once the user has walked off
    // the old start or into campus; an unknown target waits for "Coba lagi".
    if (_problem == RouteProblem.unavailable) return;
    // Off the path network: wait until the user has moved, so the message
    // is not replaced (and re-read by TalkBack) on every fix.
    if (_problem == RouteProblem.offNetwork && !moved) return;
    if (_plan == null || moved) _replan();
  }

  /// Checks in order: a usable fix, inside campus, then the route itself.
  Future<void> _replan() async {
    final request = ++_planRequest;
    final fix = _fix;
    if (fix == null || !fix.isAccurateForTrigger) {
      setState(() {
        _plan = null;
        _problem = RouteProblem.locating;
      });
      return;
    }
    if (!_services.map.isInsideCampus(fix.position)) {
      setState(() {
        _plan = null;
        _plannedFrom = fix.position;
        _problem = RouteProblem.outsideCampus;
      });
      return;
    }
    if (!_services.map.isInsideCampus(_target.point)) {
      setState(() {
        _plan = null;
        _problem = RouteProblem.unavailable;
      });
      return;
    }
    // The planner starts from the doors of the building the user is in, as
    // the navigation controller does; plan only once the POIs are loaded so
    // the preview matches the walk (the POI stream plans again on arrival).
    if (!_poisLoaded) {
      setState(() {
        _plan = null;
        _problem = null;
      });
      return;
    }
    setState(() {
      _planning = true;
      _problem = null;
    });
    WalkingRoute? plan;
    RouteProblem? problem;
    try {
      plan = await planWalkingRoute(
        routing: _services.routing,
        from: fix.position,
        target: _target,
        pois: _pois,
      );
      if (plan.path.length < 2) problem = RouteProblem.unavailable;
    } on RouteStartOffNetworkException {
      problem = RouteProblem.offNetwork;
    } catch (_) {
      problem = RouteProblem.unavailable;
    }
    if (!mounted || request != _planRequest) return;
    setState(() {
      _planning = false;
      _plannedFrom = fix.position;
      _problem = problem;
      _plan = problem == null ? plan : null;
    });
    if (problem == null) _afterFrame(_fitPreview);
  }

  // ---- Start and end ----

  bool get _sessionRunning {
    final mode = _services.session.current.mode;
    return mode == SessionMode.navigation || mode == SessionMode.trail;
  }

  Future<void> _defaultStart() async {
    await _services.session.start(SessionMode.navigation);
    await _services.navigation.start(_target);
  }

  Future<void> _defaultEnd() async {
    await _services.navigation.stop();
    await _services.session.end();
  }

  Future<void> _stopRoute() => (widget.end ?? _defaultEnd)();

  /// Two voices never play together (PRD §10): a narration or prompt still
  /// playing is paused, so the user can resume it later.
  void _pauseNarration() {
    final audio = _services.audio;
    if (audio.current.status == PlaybackStatus.playing) {
      unawaited(audio.pause());
    }
  }

  Future<void> _start() async {
    if (_starting || _plan == null) return;
    _pauseNarration();
    setState(() => _starting = true);
    final navigation = _services.navigation;
    try {
      await (widget.start ?? _defaultStart)();
      var state = navigation.current;
      // An inaccurate fix leaves the controller waiting for a usable one.
      if (state.status == NavigationStatus.calculating) {
        state = await navigation.state
            .where((state) => state.status != NavigationStatus.calculating)
            .timeout(const Duration(seconds: 12))
            .first;
      }
      if (!mounted) {
        await _stopRoute();
        return;
      }
      final walking =
          state.status == NavigationStatus.arrived ||
          (_activeStatuses.contains(state.status) &&
              (state.route?.path.length ?? 0) >= 2);
      if (!walking) {
        await _failStart(_currentProblem());
        return;
      }
      setState(() {
        _navigation = state;
        _phase = _Phase.active;
      });
      if (state.status == NavigationStatus.arrived) {
        _recommendAfter(state.target);
      } else if (_fix?.position case final position?) {
        // Close in on the walker: street level, nearer than the preview.
        _afterFrame(() => _map.currentState?.flyTo(position, zoom: 18.5));
      }
    } on TimeoutException {
      await _failStart(RouteProblem.locating);
    } catch (_) {
      await _failStart(_currentProblem());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  RouteProblem _currentProblem() {
    final fix = _fix ?? _services.location.lastFix;
    if (fix == null || !fix.isAccurateForTrigger) return RouteProblem.locating;
    if (!_services.map.isInsideCampus(fix.position)) {
      return RouteProblem.outsideCampus;
    }
    return RouteProblem.unavailable;
  }

  Future<void> _failStart(RouteProblem problem) async {
    if (_sessionRunning) {
      await _stopRoute();
    } else {
      await _services.navigation.stop();
    }
    if (!mounted) return;
    setState(() {
      _phase = _Phase.preview;
      _plan = null;
      _problem = problem;
    });
  }

  /// Akhiri rute and Selesai: stop, then return to where Rute was tapped.
  Future<void> _end() async {
    if (_ending) return;
    setState(() => _ending = true);
    try {
      await _stopRoute();
    } finally {
      if (mounted) {
        setState(() => _ending = false);
        _close();
      }
    }
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    final route = ModalRoute.of(context);
    if (route == null) return;
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else if (route.isActive) {
      route.navigator?.removeRoute(route);
    }
  }

  void _onNavigation(NavigationState state) {
    if (!mounted) return;
    final arrived =
        state.status == NavigationStatus.arrived &&
        _navigation.status != NavigationStatus.arrived;
    setState(() => _navigation = state);
    if (_phase != _Phase.active || _starting || _ending) return;
    // Ended elsewhere: the session timed out or Trail was stopped.
    if (state.status == NavigationStatus.idle) {
      _close();
      return;
    }
    if (arrived) _recommendAfter(state.target);
  }

  // ---- Arrival (UI07) ----

  /// Next POIs from where the user now stands, excluding the one reached.
  /// Nothing is logged (PRD §15.5, rules §5.1).
  Future<void> _recommendAfter(NavigationTarget? target) async {
    if (widget.trail || target == null) return;
    _recommendation = null;
    final request = ++_recommendRequest;
    final from = _fix?.position ?? target.point;
    try {
      final result = await _services.recommendations.recommend(
        from: from,
        afterPoiId: target.kind == NavigationTargetKind.poi ? target.id : null,
      );
      final pois = await _services.pois.watchPois().first;
      if (!mounted || request != _recommendRequest) return;
      setState(
        () => _recommendation = RecommendationView.resolve(
          result,
          pois: pois,
          from: from,
          trailActive: _services.trail.current.active,
        ),
      );
    } catch (_) {
      // Recommendations are optional; the arrival card stands on its own.
    }
  }

  /// A recommended POI opens its own preview on this map; the finished
  /// route ends first, so no session runs until "Mulai rute" again.
  Future<void> _previewNext(Poi poi) async {
    if (_ending) return;
    setState(() => _ending = true);
    try {
      await _stopRoute();
    } finally {
      if (mounted) setState(() => _ending = false);
    }
    if (!mounted) return;
    _recommendRequest++;
    setState(() {
      _target = NavigationTarget.poi(poi);
      _recommendation = null;
      _phase = _Phase.preview;
      _plan = null;
      _plannedFrom = null;
      _problem = null;
    });
    _replan();
  }

  /// Opened from the arrival card, so without `featureUsed` (PRD §15.5).
  /// Its Rute works as on Cari: the detail closes, then this map previews.
  Future<void> _openDetail(Poi poi) async {
    var routeRequested = false;
    await Navigator.of(context).push<void>(
      AgamMotion.route(
        (_) => PoiDetailScreen(
          activity: null,
          poi: poi,
          audio: _services.audio,
          settings: _services.settings,
          checkedIn: false,
          navigationAvailable: !widget.trail,
          onNavigate: () async {
            routeRequested = true;
          },
        ),
      ),
    );
    if (mounted && routeRequested) await _previewNext(poi);
  }

  // ---- Camera ----

  void _afterFrame(VoidCallback action) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) action();
      });

  void _fit(List<GeoPoint> points) {
    final map = _map.currentState;
    final mapBox = _map.currentContext?.findRenderObject() as RenderBox?;
    final window = _mapWindow.currentContext?.findRenderObject() as RenderBox?;
    if (map == null || mapBox == null || window == null) return;
    if (!mapBox.hasSize || !window.hasSize) return;
    // Leave room around the path and the destination marker's label.
    if (window.size.width <= 80 || window.size.height <= 56) {
      if (points.isNotEmpty) map.focusOn(points.first);
      return;
    }
    final origin =
        window.localToGlobal(Offset.zero) - mapBox.localToGlobal(Offset.zero);
    map.fitPoints(
      points,
      padding: EdgeInsets.fromLTRB(
        origin.dx + 40,
        origin.dy + 22,
        math.max(0, mapBox.size.width - origin.dx - window.size.width) + 40,
        math.max(0, mapBox.size.height - origin.dy - window.size.height) + 34,
      ),
    );
  }

  /// The whole walk, from the user to the access point.
  void _fitPreview() {
    if (!_mapReady || _phase != _Phase.preview) return;
    _fit([?_fix?.position, ...?_plan?.path, _target.point]);
  }

  /// The start of a walk in progress, at a legible zoom.
  void _fitStart() {
    final path = _activePath;
    final points = <GeoPoint>[?_fix?.position];
    var distance = 0.0;
    for (var i = 0; i < path.length; i++) {
      if (i > 0) distance += path[i - 1].distanceTo(path[i]);
      if (distance > 180 && i > 1) break;
      points.add(path[i]);
    }
    _fit(points);
  }

  void _onMapReady() {
    _mapReady = true;
    if (_phase == _Phase.preview) {
      _fitPreview();
    } else {
      _fitStart();
    }
  }

  List<GeoPoint> get _activePath => switch (_navigation.status) {
    NavigationStatus.onRoute ||
    NavigationStatus.offRoute ||
    NavigationStatus.rerouting => _navigation.route?.path ?? const [],
    _ => const [],
  };

  // ---- Build ----

  bool get _arrived =>
      _phase == _Phase.active && _navigation.status == NavigationStatus.arrived;

  NavigationTarget get _shownTarget =>
      _phase == _Phase.active ? (_navigation.target ?? _target) : _target;

  void _onPop() {
    if (_starting || _ending) return;
    // Trail keeps going in its tab; a single route ends with the screen.
    if (widget.trail) {
      _close();
    } else {
      _end();
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _shownTarget;
    final position = _fix?.position;
    final path = _phase == _Phase.preview
        ? (_plan?.path ?? const <GeoPoint>[])
        : _activePath;
    final route = ModalRoute.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final rise = route?.animation;

    Widget bottom = _bottomCard(target);
    if (rise != null && !reduceMotion) {
      // The card rises over the map as the page opens and drops on the
      // way out, both on the strong ease-out.
      bottom = SlideTransition(
        position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: rise,
            curve: AgamMotion.easeOut,
            reverseCurve: AgamMotion.easeOut.flipped,
          ),
        ),
        child: bottom,
      );
    }

    return PopScope(
      canPop: _phase == _Phase.preview && !_starting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPop();
      },
      child: Scaffold(
        backgroundColor: AgamColors.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Shown until the map's tiles are drawn, instead of black.
            const ColoredBox(color: AgamColors.fill),
            OfflineCampusMap(
              key: _map,
              config: _services.map,
              pois: const [],
              onSelectPoi: (_) {},
              userPosition: position,
              userAccuracyM: _fix?.accuracyM,
              initialFocus: position ?? path.firstOrNull ?? target.point,
              onMapReady: _onMapReady,
              routePath: path,
              // The straight walk from the user onto the path or out of a
              // building door is not mapped; drawn apart from the route.
              routeLeadIn:
                  path.length >= 2 &&
                  position != null &&
                  path.first.distanceTo(path[1]) > 1,
              highlight: MapHighlight(
                point: path.lastOrNull ?? target.point,
                label: target.name,
                icon: target.kind == NavigationTargetKind.poi
                    ? Icons.apartment_rounded
                    : Icons.place_rounded,
              ),
              attributionPadding: null,
            ),
            SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topSlot(),
                  Expanded(child: SizedBox.expand(key: _mapWindow)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: MapAttribution(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FloatingIconButton(
                        tooltip: 'Pusatkan lokasi saya',
                        icon: Icons.my_location_rounded,
                        onPressed: position == null
                            ? null
                            : () => _fit([position]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  bottom,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Back button in the preview; the instruction panel while walking. The
  /// panel comes down from the top in 280 ms and leaves in 200 ms.
  Widget _topSlot() {
    final Widget child;
    if (_phase == _Phase.preview) {
      child = Align(
        key: const ValueKey('preview-top'),
        alignment: Alignment.centerLeft,
        child: _FloatingIconButton(
          tooltip: 'Kembali',
          icon: Icons.arrow_back_rounded,
          foreground: AgamColors.ink,
          onPressed: _starting ? null : () => Navigator.of(context).maybePop(),
        ),
      );
    } else if (_arrived) {
      child = const SizedBox(key: ValueKey('arrived-top'), width: 0);
    } else {
      child = _InstructionPanel(
        key: const ValueKey('instruction'),
        state: _navigation,
      );
    }
    return AnimatedSwitcher(
      duration: AgamMotion.duration(context, 280),
      reverseDuration: AgamMotion.duration(context, 200),
      switchInCurve: AgamMotion.easeOut,
      switchOutCurve: AgamMotion.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child.key == const ValueKey('instruction')
            ? SlideTransition(
                position: Tween(
                  begin: const Offset(0, -.35),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              )
            : child,
      ),
      child: child,
    );
  }

  /// One card at the bottom that changes with the phase; its height glides
  /// while the old content fades out and the new fades in.
  Widget _bottomCard(NavigationTarget target) {
    final Widget content;
    if (_phase == _Phase.preview) {
      content = _PreviewCard(
        key: ValueKey('preview-${target.id}'),
        target: target,
        plan: _plan,
        planning: _planning,
        problem: _problem,
        starting: _starting,
        onStart: _start,
        onRetry: _replan,
      );
    } else if (_arrived) {
      content = _arrivalContent(target);
    } else {
      content = _TripCard(
        key: const ValueKey('trip'),
        target: target,
        state: _navigation,
        onEnd: _ending ? null : _end,
      );
    }
    // On arrival the walk is over and "Lanjut ke mana?" needs the room, so
    // the card may cover most of the map instead of starting scrolled.
    final maxHeight =
        MediaQuery.sizeOf(context).height * (_arrived ? .85 : .62);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: AgamAnimatedSize(
        milliseconds: 280,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: AgamMotion.duration(context, 220),
          reverseDuration: AgamMotion.duration(context, 160),
          switchInCurve: AgamMotion.easeOut,
          switchOutCurve: AgamMotion.easeOut,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // The outgoing card keeps its own height while it fades.
              for (final child in previous)
                Positioned(left: 0, right: 0, bottom: 0, child: child),
              ?current,
            ],
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _arrivalContent(NavigationTarget target) {
    Poi? poi;
    if (target.kind == NavigationTargetKind.poi) {
      for (final candidate in _pois) {
        if (candidate.id == target.id) poi = candidate;
      }
    }
    final recommendation = _recommendation;
    return SingleChildScrollView(
      key: ValueKey('arrived-${target.id}'),
      reverse: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecommendationPresence(
            child: recommendation == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RecommendationCard(
                      view: recommendation,
                      onRoute: _previewNext,
                    ),
                  ),
          ),
          ArrivalCard(
            name: target.name,
            kind: target.kind,
            voice: _services.voice,
            onFinish: widget.trail ? _close : _end,
            onOpenDetail: poi == null ? null : () => _openDetail(poi!),
          ),
        ],
      ),
    );
  }
}

String _minutes(Duration eta) =>
    '~${math.max(1, (eta.inSeconds / 60).ceil())} menit';

BoxDecoration get _cardDecoration => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(AgamRadius.card),
  boxShadow: AgamShadows.floating,
);

/// The route summary before the walk: where, how far, how long, and the
/// one action that starts it.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    super.key,
    required this.target,
    required this.plan,
    required this.planning,
    required this.problem,
    required this.starting,
    required this.onStart,
    required this.onRetry,
  });

  final NavigationTarget target;
  final WalkingRoute? plan;
  final bool planning;
  final RouteProblem? problem;
  final bool starting;
  final VoidCallback onStart;
  final VoidCallback onRetry;

  bool get _unverifiedPassage =>
      plan?.steps.any(
        (step) => step.instruction.contains('belum diverifikasi'),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final plan = this.plan;
    final problem = this.problem;
    final retry =
        problem == RouteProblem.offNetwork ||
        problem == RouteProblem.unavailable;
    return DecoratedBox(
      decoration: _cardDecoration,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AgamIconTile(
                  icon: target.kind == NavigationTargetKind.poi
                      ? Icons.apartment_rounded
                      : Icons.place_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(target.name, style: AgamText.title)),
              ],
            ),
            const SizedBox(height: 12),
            if (problem != null)
              _Notice(text: WalkingNavigationScreen.problemMessage(problem))
            else if (plan == null || planning)
              Text(
                WalkingNavigationScreen.planningMessage,
                style: AgamText.label.copyWith(color: AgamColors.muted),
              )
            else
              Text(
                '${plan.distanceM.round()} m · ${_minutes(plan.eta)} '
                'jalan kaki',
                style: AgamText.label.copyWith(color: AgamColors.brand),
              ),
            if (target.isPlaceholderPoint) ...[
              const SizedBox(height: 4),
              const Text('Tujuan perkiraan', style: AgamText.caption),
            ],
            if (problem == null && plan != null && _unverifiedPassage) ...[
              const SizedBox(height: 4),
              const Text(
                WalkingNavigationScreen.passageNote,
                style: AgamText.caption,
              ),
            ],
            const SizedBox(height: 16),
            if (retry)
              AgamTonalButton(
                label: WalkingNavigationScreen.retryLabel,
                icon: Icons.refresh_rounded,
                height: 54,
                onPressed: planning ? null : onRetry,
              )
            else
              AgamPrimaryButton(
                label: WalkingNavigationScreen.startLabel,
                icon: Icons.navigation_rounded,
                height: 54,
                busy: starting,
                onPressed: plan == null || planning || starting
                    ? null
                    : onStart,
              ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AgamColors.fill,
      borderRadius: BorderRadius.circular(AgamRadius.control),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 20,
          color: AgamColors.muted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(text, style: AgamText.bodySmall),
          ),
        ),
      ],
    ),
  );
}

/// The trip status while walking: what is left and the way out.
class _TripCard extends StatelessWidget {
  const _TripCard({
    super.key,
    required this.target,
    required this.state,
    required this.onEnd,
  });

  final NavigationTarget target;
  final NavigationState state;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final distance = state.remainingDistanceM;
    final eta = state.remainingEta;
    return DecoratedBox(
      decoration: _cardDecoration,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(target.name, style: AgamText.title),
            const SizedBox(height: 4),
            Text(
              'Sisa ${distance == null ? '—' : '${distance.round()} m'}'
              ' · ${eta == null ? '—' : _minutes(eta)}',
              style: AgamText.label.copyWith(color: AgamColors.brand),
            ),
            if (target.isPlaceholderPoint) ...[
              const SizedBox(height: 4),
              const Text('Tujuan perkiraan', style: AgamText.caption),
            ],
            const SizedBox(height: 12),
            AgamTonalButton(
              label: 'Akhiri rute',
              icon: Icons.close_rounded,
              onPressed: onEnd,
              foreground: AgamColors.danger,
              background: AgamColors.dangerTint,
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionPanel extends StatelessWidget {
  const _InstructionPanel({super.key, required this.state});

  final NavigationState state;

  @override
  Widget build(BuildContext context) {
    final step = state.currentStep;
    final icon = switch (step?.maneuver) {
      Maneuver.turnLeft => Icons.turn_left_rounded,
      Maneuver.turnRight => Icons.turn_right_rounded,
      Maneuver.slightLeft => Icons.turn_slight_left_rounded,
      Maneuver.slightRight => Icons.turn_slight_right_rounded,
      Maneuver.depart || Maneuver.straight => Icons.straight_rounded,
      Maneuver.arrive => Icons.flag_rounded,
      null => Icons.directions_walk_rounded,
    };
    final instruction = switch (state.status) {
      NavigationStatus.offRoute => 'Anda berada di luar jalur.',
      NavigationStatus.rerouting => 'Menghitung ulang rute…',
      NavigationStatus.error => 'Rute tidak tersedia dari posisi saat ini.',
      _ => step?.instruction ?? 'Menyiapkan arahan…',
    };
    return AgamGround(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AgamIconTile(
            icon: icon,
            size: 48,
            foreground: Colors.white,
            background: Colors.white.withValues(alpha: .14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                instruction,
                style: AgamText.headline.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A round white control floating on the map, with press feedback.
class _FloatingIconButton extends StatelessWidget {
  const _FloatingIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.foreground = AgamColors.brand,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color foreground;

  @override
  Widget build(BuildContext context) => AgamPressFeedback(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AgamShadows.floating,
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: foreground,
          disabledBackgroundColor: Colors.white,
          fixedSize: const Size.square(48),
        ),
        onPressed: onPressed,
      ),
    ),
  );
}
