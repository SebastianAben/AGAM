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
import 'widgets/trip_status_card.dart';

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

  /// A facility inside a building: the route ends at the building door.
  static const doorNote =
      'Rute menuju pintu gedung; lanjutkan ke dalam gedung.';

  /// Shown while walking when no offline Indonesian TTS voice is installed
  /// (PRD §10, §19): the turn instructions stay on screen only.
  static const voiceNote =
      'Suara Bahasa Indonesia belum terpasang, jadi arahan hanya tampil di '
      'layar. Pasang data suaranya di pengaturan text-to-speech (TTS) '
      'Android.';

  /// How long the "Melewati …" pill stays for a POI passed on the way.
  static const briefPillDuration = Duration(seconds: 4);

  static String passingLabel(String name) => 'Melewati $name';

  static String approachingLabel(String name) => 'Anda mendekati $name';

  static String trailCompleteNote(int visited, int total) =>
      'Orientation Trail selesai ($visited/$total). Lencana Penjelajah '
      'Ganesha terbuka.';

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

class _WalkingNavigationScreenState extends State<WalkingNavigationScreen>
    with WidgetsBindingObserver {
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

  // Voice guidance (B10): asked when the walk starts and on resume, so an
  // Indonesian voice installed meanwhile clears the notice.
  bool _voiceAvailable = true;
  bool _voiceNoticeDismissed = false;
  int _voiceRequest = 0;

  // A POI passed on the way (brief trigger) and a Trail prompt (full).
  Poi? _passing;
  Timer? _passingTimer;
  Poi? _prompted;

  // The 10th Trail stop: the session has ended, the arrival card stays.
  bool _trailFinished = false;

  // Camera follow while walking; off once the user moves the map.
  bool _followUser = true;
  WalkingRoute? _lastActiveRoute;

  StreamSubscription<LocationFix>? _positions;
  StreamSubscription<NavigationState>? _navigationStates;
  StreamSubscription<List<Poi>>? _poiStream;
  StreamSubscription<PoiTriggerEvent>? _triggers;
  StreamSubscription<TrailProgress>? _trailProgress;

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
    _lastActiveRoute = _navigation.route;
    WidgetsBinding.instance.addObserver(this);
    _fix = _services.location.lastFix;
    _positions = _services.location.positions.listen(_onFix);
    _navigationStates = _services.navigation.state.listen(_onNavigation);
    _triggers = _services.session.triggers.listen(_onTrigger);
    if (widget.trail) {
      // Check-in can land after arrival; the completion note follows it.
      _trailProgress = _services.trail.progress.listen((_) {
        if (mounted) setState(() {});
      });
    }
    _poiStream = _services.pois.watchPois().listen((pois) {
      if (!mounted) return;
      final first = !_poisLoaded;
      _pois = pois;
      _poisLoaded = true;
      if (first && _phase == _Phase.preview) _replan();
    });
    if (_phase == _Phase.preview) {
      _replan();
    } else {
      _checkVoice();
      if (_navigation.status == NavigationStatus.arrived) {
        _recommendAfter(_navigation.target);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passingTimer?.cancel();
    _positions?.cancel();
    _navigationStates?.cancel();
    _poiStream?.cancel();
    _triggers?.cancel();
    _trailProgress?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Android's TTS settings: the voice may be installed now.
    if (state == AppLifecycleState.resumed) _checkVoice();
  }

  // ---- Voice guidance (PRD §10) ----

  Future<void> _checkVoice() async {
    if (_phase != _Phase.active) return;
    final request = ++_voiceRequest;
    bool available;
    try {
      available = await _services.voice.isAvailable();
    } catch (_) {
      available = false;
    }
    if (!mounted || request != _voiceRequest) return;
    if (available != _voiceAvailable) {
      setState(() => _voiceAvailable = available);
    }
  }

  bool get _showVoiceNotice =>
      _phase == _Phase.active &&
      !_arrived &&
      !_voiceAvailable &&
      !_voiceNoticeDismissed;

  // ---- POIs on the way ----

  Poi? _poiById(String id) {
    for (final poi in _pois) {
      if (poi.id == id) return poi;
    }
    return null;
  }

  /// Navigation passes other buildings quietly (brief: a pill, no audio).
  /// Trail plays its prompt (full), so the card it belongs to is shown here
  /// too: this map covers the Trail tab while walking.
  void _onTrigger(PoiTriggerEvent event) {
    if (!mounted || _closed || _trailFinished || _arrived) return;
    final poi = _poiById(event.poiId);
    // An unknown POI shows nothing rather than a made-up name.
    if (poi == null) return;
    switch (event.response) {
      case TriggerResponse.brief:
        if (_phase != _Phase.active || poi.id == _shownTarget.id) return;
        _passingTimer?.cancel();
        setState(() => _passing = poi);
        _passingTimer = Timer(WalkingNavigationScreen.briefPillDuration, () {
          if (mounted) setState(() => _passing = null);
        });
      case TriggerResponse.full:
        if (!widget.trail) return;
        setState(() => _prompted = poi);
    }
  }

  Future<void> _listenPrompted(Poi poi) async {
    final audio = _services.audio;
    final state = audio.current;
    final playing =
        state.clip?.poiId == poi.id &&
        state.clip?.kind == AudioClipKind.narration &&
        state.status == PlaybackStatus.playing;
    try {
      if (playing) {
        await audio.pause();
      } else {
        await audio.play(
          AudioClip(poiId: poi.id, kind: AudioClipKind.narration),
        );
      }
    } catch (_) {
      // Playback errors surface in the audio state; the card stays.
    }
  }

  Future<void> _skipPrompted(Poi poi) async {
    setState(() => _prompted = null);
    final audio = _services.audio;
    final clip = audio.current.clip;
    if (clip?.poiId == poi.id && clip?.kind == AudioClipKind.prompt) {
      try {
        await audio.stop();
      } catch (_) {}
    }
  }

  // ---- Preview ----

  void _onFix(LocationFix fix) {
    if (!mounted) return;
    setState(() => _fix = fix);
    if (_phase == _Phase.active && !_arrived && _followUser && _mapReady) {
      _map.currentState?.follow(fix.position);
    }
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
      final first = _problem != RouteProblem.outsideCampus;
      setState(() {
        _plan = null;
        _plannedFrom = fix.position;
        _problem = RouteProblem.outsideCampus;
      });
      // Show the destination on campus, once, not the void around the user.
      if (first) _afterFrame(_fitPreview);
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
    // Explore keeps running if this route cannot start (B17).
    final priorMode = _services.session.current.mode;
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
        await _failStart(_currentProblem(), priorMode);
        return;
      }
      setState(() {
        _navigation = state;
        _phase = _Phase.active;
        _followUser = true;
        _lastActiveRoute = state.route;
      });
      _checkVoice();
      if (state.status == NavigationStatus.arrived) {
        _recommendAfter(state.target);
      } else if (_fix?.position case final position?) {
        // Close in on the walker: street level, nearer than the preview.
        _afterFrame(() => _map.currentState?.flyTo(position, zoom: 18.5));
      }
    } on TimeoutException {
      await _failStart(RouteProblem.locating, priorMode);
    } catch (_) {
      await _failStart(_currentProblem(), priorMode);
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

  /// Back to the preview with the reason. A session that ran before "Mulai
  /// rute" is kept: Explore returns to Explore instead of ending.
  Future<void> _failStart(RouteProblem problem, SessionMode priorMode) async {
    try {
      if (priorMode == SessionMode.explore) {
        // A caller's own end (Trail) still runs; if Trail was freshly started
        // from Explore, stop it too before returning to Explore.
        if (widget.end != null) {
          await _stopRoute();
        } else {
          await _services.navigation.stop();
        }
        if (widget.trail) await _services.trail.stop();
        if (_services.session.current.mode != SessionMode.explore) {
          await _services.session.start(SessionMode.explore);
        }
      } else if (priorMode == SessionMode.none && widget.trail) {
        // A brand-new Trail whose first route failed must not stay active.
        await _services.navigation.stop();
        await _services.session.end();
        await _services.trail.stop();
      } else if (_sessionRunning) {
        await _stopRoute();
      } else {
        await _services.navigation.stop();
      }
    } catch (_) {
      // The preview still shows the reason; the user can try again.
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

  /// The last Trail stop ends the session (10/10) right after arrival. The
  /// arrival card stays so `tiba` can finish and Selesai closes it.
  bool _finishesTrail(NavigationState state) {
    if (!widget.trail || _phase != _Phase.active) return false;
    if (state.status != NavigationStatus.idle) return false;
    final trail = _services.trail.current;
    if (!trail.isComplete) return false;
    final previous = _navigation;
    return previous.status == NavigationStatus.arrived ||
        (previous.target != null &&
            trail.visited.contains(previous.target!.id));
  }

  void _onNavigation(NavigationState state) {
    if (!mounted || _trailFinished) return;
    if (!_starting && !_ending && _finishesTrail(state)) {
      final target = _navigation.target ?? _target;
      setState(() {
        _trailFinished = true;
        _prompted = null;
        _passing = null;
        // Kept as an arrival: the session has ended, the card has not.
        _navigation = NavigationState(
          status: NavigationStatus.arrived,
          target: target,
        );
      });
      return;
    }
    final arrived =
        state.status == NavigationStatus.arrived &&
        _navigation.status != NavigationStatus.arrived;
    setState(() {
      _navigation = state;
      if (arrived) {
        _prompted = null;
        _passing = null;
      }
    });
    if (_phase != _Phase.active || _starting || _ending) return;
    // Ended elsewhere: the session timed out or Trail was stopped.
    if (state.status == NavigationStatus.idle) {
      _close();
      return;
    }
    if (arrived) _recommendAfter(state.target);
    final route = state.route;
    if (state.status == NavigationStatus.onRoute &&
        route != null &&
        !identical(route, _lastActiveRoute)) {
      final rerouted = _lastActiveRoute != null;
      _lastActiveRoute = route;
      if (rerouted) _afterFrame(_refitAfterReroute);
    }
  }

  /// A new route keeps the walker and its start in view: recentered while
  /// following, otherwise fitted to the user and the first part of it.
  void _refitAfterReroute() {
    if (_phase != _Phase.active || _arrived) return;
    final position = _fix?.position;
    if (_followUser && position != null) {
      _map.currentState?.follow(position);
    } else {
      _fitStart();
    }
  }

  void _onUserMovedMap() {
    if (_phase == _Phase.active && _followUser) {
      setState(() => _followUser = false);
    }
  }

  /// "Pusatkan lokasi saya": while walking it also turns following back on.
  void _recenter(GeoPoint position) {
    if (_phase == _Phase.active && !_arrived) {
      setState(() => _followUser = true);
      _map.currentState?.flyTo(position, zoom: 18.5);
    } else {
      _fit([position]);
    }
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
        afterFacilityId: target.kind == NavigationTargetKind.facility
            ? target.id
            : null,
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
      _prompted = null;
      _passing = null;
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
          checkedIn: _services.trail.current.visited.contains(poi.id),
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
    // Outside campus the offline tiles end; frame the destination alone.
    if (_problem == RouteProblem.outsideCampus) {
      _map.currentState?.focusOn(_target.point);
      return;
    }
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

    Widget buildBottom(double availableHeight) {
      Widget bottom = _bottomCard(target, availableHeight: availableHeight);
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
      return bottom;
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
              onUserInteract: _onUserMovedMap,
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
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _topSlot(),
                    // Notices float over the map window instead of resizing
                    // it, so showing one never shifts the camera's framing.
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SizedBox.expand(key: _mapWindow),
                          Align(
                            alignment: Alignment.topCenter,
                            child: _topNotices(),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: _promptSlot(),
                          ),
                        ],
                      ),
                    ),
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
                          // Filled while the camera follows the walker; white
                          // once the user has moved the map away.
                          toggleable: _phase == _Phase.active && !_arrived,
                          active:
                              _phase == _Phase.active &&
                              !_arrived &&
                              _followUser &&
                              position != null,
                          onPressed: position == null
                              ? null
                              : () => _recenter(position),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    buildBottom(constraints.maxHeight),
                  ],
                ),
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

  /// The voice notice and the "Melewati …" pill, under the instruction
  /// panel. Both fade and drop 6 px in; reduced motion shows them at rest.
  Widget _topNotices() {
    final passing = _passing;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Presence(
            child: _showVoiceNotice
                ? _VoiceNotice(
                    key: const ValueKey('voice-notice'),
                    onDismiss: () =>
                        setState(() => _voiceNoticeDismissed = true),
                  )
                : null,
          ),
          _Presence(
            child: passing == null || _arrived
                ? null
                : Padding(
                    key: ValueKey('passing-${passing.id}'),
                    padding: EdgeInsets.only(top: _showVoiceNotice ? 8 : 0),
                    child: _PassingPill(name: passing.name),
                  ),
          ),
        ],
      ),
    );
  }

  /// The Trail prompt card for a POI reached on the way (UI03 actions).
  Widget _promptSlot() {
    final poi = _prompted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Presence(
        child: poi == null || _arrived
            ? null
            : _TrailPromptCard(
                key: ValueKey('prompt-${poi.id}'),
                poi: poi,
                audio: _services.audio,
                onListen: () => _listenPrompted(poi),
                onView: () => _openDetail(poi),
                onSkip: () => _skipPrompted(poi),
              ),
      ),
    );
  }

  /// One card at the bottom that changes with the phase; its height glides
  /// while the old content fades out and the new fades in.
  Widget _bottomCard(
    NavigationTarget target, {
    required double availableHeight,
  }) {
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
    // On arrival the walk is over and "Lanjut ke mana?" needs the room, while
    // leaving space for the fading top bar and map attribution row above it.
    final maxHeight = math.max(
      120.0,
      math.min(availableHeight * (_arrived ? .78 : .62), availableHeight - 180),
    );
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
    final trail = _services.trail.current;
    final completionNote = widget.trail && trail.isComplete
        ? WalkingNavigationScreen.trailCompleteNote(
            trail.visitedCount,
            trail.total,
          )
        : null;
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
            locationHint: target.locationHint,
            enterBuilding: target.candidates.isNotEmpty,
            completionNote: completionNote,
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

  String? get _indoorHint {
    if (target.kind != NavigationTargetKind.facility) return null;
    final hint = target.locationHint?.trim();
    return hint == null || hint.isEmpty ? null : hint;
  }

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
            if (_indoorHint case final hint?) ...[
              const SizedBox(height: 12),
              _IndoorHintRow(hint: hint, toDoor: target.candidates.isNotEmpty),
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
  Widget build(BuildContext context) => TripStatusCard(
    destination: target.name,
    remainingDistanceM: state.remainingDistanceM,
    remainingEta: state.remainingEta,
    isApproximate: target.isPlaceholderPoint,
    locationHint: target.kind == NavigationTargetKind.facility
        ? target.locationHint
        : null,
    onEnd: onEnd,
  );
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
    this.active = false,
    this.toggleable = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color foreground;

  /// Filled in the brand colour while the state it controls is on (the
  /// camera following the walker); the colours ease over 200 ms.
  final bool active;

  /// Whether [active] is a state screen readers should hear as on/off.
  final bool toggleable;

  @override
  Widget build(BuildContext context) => AgamPressFeedback(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AgamShadows.floating,
      ),
      child: Semantics(
        toggled: toggleable && onPressed != null ? active : null,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: active ? 1 : 0),
          duration: AgamMotion.duration(context, 200),
          curve: AgamMotion.easeOut,
          builder: (context, t, _) => IconButton(
            tooltip: tooltip,
            icon: Icon(icon),
            style: IconButton.styleFrom(
              backgroundColor: Color.lerp(Colors.white, foreground, t),
              foregroundColor: Color.lerp(foreground, Colors.white, t),
              disabledBackgroundColor: Colors.white,
              fixedSize: const Size.square(48),
            ),
            onPressed: onPressed,
          ),
        ),
      ),
    ),
  );
}

/// Fades and drops a small overlay in (200 ms) and out (140 ms) on the
/// strong ease-out. `null` hides it; reduced motion swaps without motion.
class _Presence extends StatelessWidget {
  const _Presence({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AgamMotion.duration(context, 200),
    reverseDuration: AgamMotion.duration(context, 140),
    switchInCurve: AgamMotion.easeOut,
    switchOutCurve: AgamMotion.easeOut,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      children: [...previous, ?current],
    ),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, -.12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: child ?? const SizedBox.shrink(key: ValueKey('none')),
  );
}

/// Where a facility is inside its building, under the route summary.
class _IndoorHintRow extends StatelessWidget {
  const _IndoorHintRow({required this.hint, required this.toDoor});

  final String hint;

  /// The route ends at the building's door, not at the facility itself.
  final bool toDoor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
    decoration: BoxDecoration(
      color: AgamColors.tint,
      borderRadius: BorderRadius.circular(AgamRadius.control),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.meeting_room_rounded,
            size: 18,
            color: AgamColors.brand,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hint, style: AgamText.label.copyWith(color: AgamColors.ink)),
              if (toDoor) ...[
                const SizedBox(height: 2),
                const Text(
                  WalkingNavigationScreen.doorNote,
                  style: AgamText.caption,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// No Indonesian voice: the instructions are visual only. Calm, compact,
/// and dismissible for the rest of this walk.
class _VoiceNotice extends StatelessWidget {
  const _VoiceNotice({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: _cardDecoration.copyWith(
      borderRadius: BorderRadius.circular(AgamRadius.tile),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      child: Row(
        children: [
          const Icon(
            Icons.volume_off_rounded,
            size: 18,
            color: AgamColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(
                liveRegion: true,
                child: const Text(
                  WalkingNavigationScreen.voiceNote,
                  style: AgamText.caption,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tutup pemberitahuan suara',
            onPressed: onDismiss,
            color: AgamColors.muted,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    ),
  );
}

/// A building passed on the way: a quiet pill, gone after a few seconds.
class _PassingPill extends StatelessWidget {
  const _PassingPill({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
      decoration: BoxDecoration(
        color: AgamColors.ink.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(999),
        boxShadow: AgamShadows.floating,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.apartment_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              WalkingNavigationScreen.passingLabel(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The Trail prompt for a POI reached while this map covers the Trail tab:
/// the voice prompt is already playing, so its card must be visible too.
class _TrailPromptCard extends StatelessWidget {
  const _TrailPromptCard({
    super.key,
    required this.poi,
    required this.audio,
    required this.onListen,
    required this.onView,
    required this.onSkip,
  });

  final Poi poi;
  final AudioService audio;
  final VoidCallback onListen;
  final VoidCallback onView;
  final VoidCallback onSkip;

  bool get _narrationAvailable =>
      poi.metadata.approved &&
      !poi.metadata.isPlaceholder &&
      poi.media.narrationAudio?.isNotEmpty == true;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: _cardDecoration,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AgamIconTile(icon: Icons.apartment_rounded, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  header: true,
                  child: Text(
                    WalkingNavigationScreen.approachingLabel(poi.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AgamText.label.copyWith(color: AgamColors.ink),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<PlaybackState>(
            stream: audio.state,
            initialData: audio.current,
            builder: (context, snapshot) {
              final state = snapshot.data;
              final playing =
                  state?.clip?.poiId == poi.id &&
                  state?.clip?.kind == AudioClipKind.narration &&
                  state?.status == PlaybackStatus.playing;
              return AgamPrimaryButton(
                height: 48,
                onPressed: _narrationAvailable ? onListen : null,
                icon: playing ? Icons.pause_rounded : Icons.headphones_rounded,
                label: _narrationAvailable
                    ? (playing ? 'Jeda cerita' : 'Dengarkan')
                    : 'Narasi belum tersedia',
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AgamTonalButton(
                  onPressed: onView,
                  icon: Icons.info_outline_rounded,
                  label: 'Lihat',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AgamTonalButton(
                  onPressed: onSkip,
                  icon: Icons.skip_next_rounded,
                  foreground: AgamColors.muted,
                  label: 'Lewati',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
