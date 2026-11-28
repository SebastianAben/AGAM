import 'dart:async';
import 'dart:math' as math;

import '../../contracts/contracts.dart';
import 'campus_routing_service.dart';
import 'route_planner.dart';

/// Holds only the current route and active progress in memory.
class DeviceNavigationController implements NavigationController {
  DeviceNavigationController({
    required this._location,
    required this._routing,
    required this._map,
    required this._session,
    this.arriveAtRouteEnd = false,
    this._pois,
  });

  static const _preTurnLeadM = 10.0;
  static const _turnPassedM = 10.0;
  static const _rerouteRetryDistanceM = 10.0;

  final LocationService _location;
  final RoutingService _routing;

  /// Latest POIs, so a start inside a building may leave by any of its
  /// access points (see [planWalkingRoute]). Without it only the nearest
  /// path is snapped.
  final List<Poi> Function()? _pois;
  final MapConfig _map;
  final SessionController _session;
  final bool arriveAtRouteEnd;
  final _states = StreamController<NavigationState>.broadcast();

  StreamSubscription<LocationFix>? _positions;
  StreamSubscription<SessionState>? _sessions;
  NavigationState _current = const NavigationState.idle();
  int _generation = 0;
  bool _calculating = false;
  double _progressM = 0;
  GeoPoint? _lastFailedRouteFrom;

  @override
  NavigationState get current => _current;

  @override
  Stream<NavigationState> get state => _states.stream;

  @override
  Future<void> start(NavigationTarget target) async {
    final generation = ++_generation;
    _detach();
    _progressM = 0;
    final mode = _session.current.mode;
    if ((mode != SessionMode.navigation && mode != SessionMode.trail) ||
        !_map.isInsideCampus(target.point)) {
      _publish(NavigationState(status: NavigationStatus.error, target: target));
      return;
    }
    _publish(
      NavigationState(status: NavigationStatus.calculating, target: target),
    );
    _sessions = _session.state.listen((state) {
      if (generation == _generation && state.mode != mode) {
        unawaited(stop());
      }
    });
    _positions = _location.positions.listen((fix) => _onFix(fix, generation));
    final fix = _location.lastFix;
    if (fix != null) await _onFix(fix, generation);
  }

  Future<void> _onFix(LocationFix fix, int generation) async {
    final target = _current.target;
    if (generation != _generation ||
        target == null ||
        _calculating ||
        !fix.accuracyM.isFinite ||
        fix.accuracyM < 0 ||
        !fix.isAccurateForTrigger) {
      return;
    }
    final point = fix.position;
    if (!_map.isInsideCampus(point)) {
      _lastFailedRouteFrom = null;
      if (_current.status != NavigationStatus.error) {
        _publish(
          NavigationState(
            status: NavigationStatus.error,
            target: target,
            route: _current.route,
          ),
        );
      }
      return;
    }
    final route = _current.route;
    if (route != null && _isAtDestination(point, target, route)) {
      _arrive(target, route);
      return;
    }
    if (route != null) {
      final (offset, traveled) = _project(point, route);
      if (offset <= kRerouteDistanceM) {
        _lastFailedRouteFrom = null;
        _updateRoute(target, route, traveled);
        return;
      }
      final failedFrom = _lastFailedRouteFrom;
      if (failedFrom != null &&
          point.distanceTo(failedFrom) < _rerouteRetryDistanceM) {
        return;
      }
      if (_current.status != NavigationStatus.error) {
        _publish(
          NavigationState(
            status: NavigationStatus.offRoute,
            target: target,
            route: route,
          ),
        );
      }
    } else {
      final failedFrom = _lastFailedRouteFrom;
      if (failedFrom != null &&
          point.distanceTo(failedFrom) < _rerouteRetryDistanceM) {
        return;
      }
    }
    _calculating = true;
    _publish(
      NavigationState(
        status: route == null
            ? NavigationStatus.calculating
            : NavigationStatus.rerouting,
        target: target,
        route: route,
      ),
    );
    try {
      final next = await _nearestRoute(point, target);
      if (generation != _generation) return;
      _lastFailedRouteFrom = null;
      _progressM = 0;
      if (_isAtDestination(point, target, next)) {
        _arrive(target, next);
      } else {
        _updateRoute(target, next, 0);
      }
    } on RouteUnavailableException {
      if (generation == _generation) {
        _lastFailedRouteFrom = point;
        _publish(
          NavigationState(
            status: NavigationStatus.error,
            target: target,
            route: route,
          ),
        );
      }
    } finally {
      if (generation == _generation) _calculating = false;
    }
  }

  /// The access points this target may be reached at (PRD §11).
  static List<GeoPoint> _destinations(NavigationTarget target) =>
      target.candidates.isEmpty ? [target.point] : target.candidates;

  /// Routes to every access point and keeps the shortest walk, so a nearer
  /// door behind a wall does not win over one that is closer on foot. A
  /// start inside a POI also tries each of its doors (also on reroute).
  Future<WalkingRoute> _nearestRoute(GeoPoint from, NavigationTarget target) =>
      planWalkingRoute(
        routing: _routing,
        from: from,
        target: target,
        pois: _pois?.call() ?? const [],
      );

  bool _isAtDestination(
    GeoPoint position,
    NavigationTarget target,
    WalkingRoute route,
  ) {
    if (arriveAtRouteEnd && route.path.isNotEmpty) {
      return position.distanceTo(route.path.last) <= kArrivalDistanceM;
    }
    return _destinations(target)
        .any((point) => position.distanceTo(point) <= kArrivalDistanceM);
  }

  void _arrive(NavigationTarget target, WalkingRoute route) {
    final mode = _session.current.mode;
    final generation = _generation;
    _detach();
    _publish(
      NavigationState(
        status: NavigationStatus.arrived,
        target: target,
        route: route,
        remainingDistanceM: 0,
        remainingEta: Duration.zero,
      ),
    );
    // The session remains explicit and can be ended from UI07 or Settings.
    _sessions = _session.state.listen((state) {
      if (generation == _generation && state.mode != mode) unawaited(stop());
    });
  }

  void _updateRoute(
    NavigationTarget target,
    WalkingRoute route,
    double progress,
  ) {
    if (progress > _progressM) _progressM = progress;
    final remaining = (route.distanceM - _progressM).clamp(
      0.0,
      route.distanceM,
    );
    final steps = route.steps;
    final stepStarts = List<double>.filled(steps.length, 0);
    for (var i = 1; i < steps.length; i++) {
      stepStarts[i] = stepStarts[i - 1] + steps[i - 1].distanceM;
    }
    var index = 0;
    for (var i = 1; i < steps.length - 1; i++) {
      final legM = steps[i - 1].distanceM;
      final leadM = math.min(_preTurnLeadM, legM / 2);
      // Announce shortly before the corner rather than after passing it,
      // without skipping a short preceding leg before the walker moves.
      if (_progressM + leadM < stepStarts[i]) break;
      index = i;
    }
    RouteStep? activeStep;
    if (index < steps.length - 1) {
      final step = steps[index];
      final alreadyOnStep =
          _current.status == NavigationStatus.onRoute &&
          identical(_current.route, route) &&
          _current.currentStepIndex == index;
      if (alreadyOnStep &&
          _isTurnManeuver(step.maneuver) &&
          !step.instruction.contains('lorong') &&
          _progressM > stepStarts[index] + _turnPassedM) {
        activeStep = RouteStep(
          maneuver: Maneuver.straight,
          instruction: outdoorInstruction(Maneuver.straight),
          distanceM: (stepStarts[index + 1] - _progressM).clamp(
            0.0,
            route.distanceM,
          ),
          position: step.position,
        );
      }
    }
    _publish(
      NavigationState(
        status: NavigationStatus.onRoute,
        target: target,
        route: route,
        currentStepIndex: index,
        remainingDistanceM: remaining,
        remainingEta: CampusRoutingService.walkingTime(remaining),
        activeStep: activeStep,
      ),
    );
  }

  static bool _isTurnManeuver(Maneuver maneuver) => switch (maneuver) {
    Maneuver.turnLeft ||
    Maneuver.turnRight ||
    Maneuver.slightLeft ||
    Maneuver.slightRight => true,
    Maneuver.depart || Maneuver.straight || Maneuver.arrive => false,
  };

  (double, double) _project(GeoPoint point, WalkingRoute route) {
    var along = 0.0;
    var bestDistance = double.infinity;
    var bestProgress = 0.0;
    for (var i = 1; i < route.path.length; i++) {
      final a = route.path[i - 1];
      final b = route.path[i];
      final length = a.distanceTo(b);
      final projection = projectOnSegment(point, a, b);
      if (projection.distanceM < bestDistance) {
        bestDistance = projection.distanceM;
        bestProgress = along + projection.fraction * length;
      }
      along += length;
    }
    return (bestDistance, bestProgress);
  }

  @override
  Future<void> stop() async {
    ++_generation;
    _detach();
    if (_current.status != NavigationStatus.idle) {
      _publish(const NavigationState.idle());
    }
  }

  void _detach() {
    unawaited(_positions?.cancel());
    unawaited(_sessions?.cancel());
    _positions = null;
    _sessions = null;
    _calculating = false;
    _lastFailedRouteFrom = null;
  }

  void _publish(NavigationState value) {
    _current = value;
    _states.add(value);
  }
}
