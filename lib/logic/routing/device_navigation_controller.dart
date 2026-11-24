import 'dart:async';

import '../../contracts/contracts.dart';
import 'campus_routing_service.dart';

/// Holds only the current route and active progress in memory.
class DeviceNavigationController implements NavigationController {
  DeviceNavigationController({
    required this._location,
    required this._routing,
    required this._map,
    required this._session,
    this.arriveAtRouteEnd = false,
  });

  final LocationService _location;
  final RoutingService _routing;
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
      if (_current.status != NavigationStatus.error) {
        _publish(
          NavigationState(status: NavigationStatus.error, target: target),
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
        _updateRoute(target, route, traveled);
        return;
      }
      _publish(
        NavigationState(
          status: NavigationStatus.offRoute,
          target: target,
          route: route,
        ),
      );
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
      final next = await _routing.route(from: point, to: target.point);
      if (generation != _generation) return;
      _progressM = 0;
      if (_isAtDestination(point, target, next)) {
        _arrive(target, next);
      } else {
        _updateRoute(target, next, 0);
      }
    } on RouteUnavailableException {
      if (generation == _generation) {
        _publish(
          NavigationState(status: NavigationStatus.error, target: target),
        );
      }
    } finally {
      if (generation == _generation) _calculating = false;
    }
  }

  bool _isAtDestination(
    GeoPoint position,
    NavigationTarget target,
    WalkingRoute route,
  ) {
    final endpoint = arriveAtRouteEnd && route.path.isNotEmpty
        ? route.path.last
        : target.point;
    return position.distanceTo(endpoint) <= kArrivalDistanceM;
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
    var index = 0;
    var nextTurnM = 0.0;
    for (var i = 1; i < route.steps.length - 1; i++) {
      nextTurnM += route.steps[i - 1].distanceM;
      // Announce shortly before the corner rather than after passing it.
      if (_progressM + 10 < nextTurnM) break;
      index = i;
    }
    _publish(
      NavigationState(
        status: NavigationStatus.onRoute,
        target: target,
        route: route,
        currentStepIndex: index,
        remainingDistanceM: remaining,
        remainingEta: CampusRoutingService.walkingTime(remaining),
      ),
    );
  }

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
  }

  void _publish(NavigationState value) {
    _current = value;
    _states.add(value);
  }
}
