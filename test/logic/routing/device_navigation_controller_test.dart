import 'dart:async';
import 'dart:convert';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/map/agam_map_config.dart';
import 'package:agam/logic/routing/campus_routing_service.dart';
import 'package:agam/logic/routing/device_navigation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

// SYNTHETIC geometry at the equator. 0.0001° is approximately 11.1195 m.
const start = GeoPoint(0, 0);
const corner = GeoPoint(0, .001);
const north = GeoPoint(.001, .001);
const west = GeoPoint(.001, 0);
const target = NavigationTarget(
  id: 'synthetic-poi',
  name: 'Tujuan sintetis',
  kind: NavigationTargetKind.poi,
  point: north,
  isPlaceholderPoint: false,
);

String graph(List<List<GeoPoint>> paths) => jsonEncode({
  'type': 'FeatureCollection',
  'features': [
    for (final path in paths)
      {
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final point in path) [point.lng, point.lat],
          ],
        },
      },
  ],
});

void main() {
  final map = AgamMapConfig.withServiceArea(
    area: const CampusArea(
      polygon: [
        GeoPoint(-.01, -.01),
        GeoPoint(-.01, .01),
        GeoPoint(.01, .01),
        GeoPoint(.01, -.01),
      ],
    ),
    source: 'SYNTHETIC test coverage',
  );

  test(
    'Dijkstra uses shortest connected path and generates a left turn',
    () async {
      final routing = CampusRoutingService.fromGeoJson(
        graph([
          [start, corner, north],
          [
            start,
            const GeoPoint(-.001, 0),
            const GeoPoint(-.001, .001),
            corner,
          ],
        ]),
      );
      final route = await routing.route(from: start, to: north);
      expect(route.path, [start, corner, north]);
      expect(route.distanceM, closeTo(222.39, .1));
      expect(route.eta.inSeconds, 172);
      expect(route.steps.map((step) => step.maneuver), [
        Maneuver.depart,
        Maneuver.turnLeft,
        Maneuver.arrive,
      ]);
      expect(route.steps[1].distanceM, closeTo(111.195, .1));
    },
  );

  test(
    'snaps to the middle of edges and rejects disconnected or remote points',
    () async {
      final routing = CampusRoutingService.fromGeoJson(
        graph([
          [start, corner],
          [west, north],
        ]),
      );
      const a = GeoPoint(0, .0002);
      const b = GeoPoint(0, .0004);
      final route = await routing.route(from: a, to: b);
      expect(route.distanceM, closeTo(22.239, .1));
      expect(route.path.first, a);
      expect(route.path.last, b);
      await expectLater(
        routing.route(from: start, to: north),
        throwsA(isA<RouteUnavailableException>()),
      );
      await expectLater(
        routing.route(from: const GeoPoint(.01, .01), to: north),
        throwsA(isA<RouteUnavailableException>()),
      );
      expect(
        () => CampusRoutingService.fromGeoJson(
          '{"type":"FeatureCollection","features":[]}',
        ),
        throwsFormatException,
      );
    },
  );

  test('navigation advances, reroutes above 25 m, arrives within 15 m and clears on end', () async {
    final location = _Location();
    final session = _Session();
    final routing = _CountingRouting(
      CampusRoutingService.fromGeoJson(
        graph([
          [start, corner, north],
          [start, west, const GeoPoint(.0013, .00045), north],
        ]),
      ),
    );
    final controller = DeviceNavigationController(
      location: location,
      routing: routing,
      map: map,
      session: session,
    );
    final seen = <NavigationStatus>[];
    final listener = controller.state.listen((value) => seen.add(value.status));
    addTearDown(listener.cancel);
    addTearDown(location.controller.close);
    addTearDown(session.controller.close);
    addTearDown(controller.stop);
    await session.start(SessionMode.navigation);
    location.add(start);
    await controller.start(target);
    expect(routing.calls, 1);

    location.add(const GeoPoint(.00022, .00092)); // 8.9 m from the second leg.
    await Future<void>.delayed(Duration.zero);
    expect(controller.current.currentStep!.maneuver, Maneuver.turnLeft);
    expect(routing.calls, 1);

    location.add(const GeoPoint(.00022, 0)); // 24.46 m.
    await Future<void>.delayed(Duration.zero);
    expect(routing.calls, 1);

    location.add(const GeoPoint(.00023, 0)); // 25.57 m, on the alternate path.
    await Future<void>.delayed(Duration.zero);
    expect(routing.calls, 2);
    expect(
      seen,
      containsAllInOrder([
        NavigationStatus.offRoute,
        NavigationStatus.rerouting,
        NavigationStatus.onRoute,
      ]),
    );

    location.add(const GeoPoint(.001, .00086)); // 15.57 m.
    await Future<void>.delayed(Duration.zero);
    expect(controller.current.status, NavigationStatus.onRoute);

    location.add(const GeoPoint(.001, .00087)); // 14.46 m.
    await Future<void>.delayed(Duration.zero);
    expect(controller.current.status, NavigationStatus.arrived);
    await session.end();
    await Future<void>.delayed(Duration.zero);
    expect(controller.current.status, NavigationStatus.idle);
    expect(controller.current.route, isNull);
  });

  test(
    'demo arrives at the snapped path endpoint instead of the POI center',
    () async {
      // Synthetic POI center is about 20 m away from the end of the footpath.
      const demoTarget = NavigationTarget(
        id: 'synthetic-center',
        name: 'Pusat gedung sintetis',
        kind: NavigationTargetKind.poi,
        point: GeoPoint(.00018, .001),
        isPlaceholderPoint: true,
      );
      final session = _Session();
      final location = _Location()..add(start);
      final controller = DeviceNavigationController(
        location: location,
        routing: CampusRoutingService.fromGeoJson(
          graph([
            [start, corner],
          ]),
          graphOnly: true,
        ),
        map: map,
        session: session,
        arriveAtRouteEnd: true,
      );
      addTearDown(location.controller.close);
      addTearDown(session.controller.close);
      addTearDown(controller.stop);
      await session.start(SessionMode.navigation);
      await controller.start(demoTarget);
      expect(controller.current.status, NavigationStatus.onRoute);
      expect(controller.current.route!.path, [start, corner]);

      location.add(corner);
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.status, NavigationStatus.arrived);
    },
  );

  test('a calculation finishing after stop cannot revive navigation', () async {
    final session = _Session();
    final location = _Location()..add(start);
    final pending = Completer<WalkingRoute>();
    final controller = DeviceNavigationController(
      location: location,
      routing: _PendingRouting(pending),
      map: map,
      session: session,
    );
    await session.start(SessionMode.navigation);
    final starting = controller.start(target);
    await controller.stop();
    pending.complete(
      await CampusRoutingService.fromGeoJson(
        graph([
          [start, corner, north],
        ]),
      ).route(from: start, to: north),
    );
    await starting;
    expect(controller.current.status, NavigationStatus.idle);
    await location.controller.close();
    await session.controller.close();
  });
}

class _PendingRouting implements RoutingService {
  _PendingRouting(this.pending);
  final Completer<WalkingRoute> pending;

  @override
  Future<WalkingRoute> route({required GeoPoint from, required GeoPoint to}) =>
      pending.future;
}

class _CountingRouting implements RoutingService {
  _CountingRouting(this.delegate);
  final RoutingService delegate;
  int calls = 0;
  @override
  Future<WalkingRoute> route({required GeoPoint from, required GeoPoint to}) {
    calls++;
    return delegate.route(from: from, to: to);
  }
}

class _Location implements LocationService {
  final controller = StreamController<LocationFix>.broadcast();
  @override
  LocationFix? lastFix;
  @override
  Stream<LocationFix> get positions => controller.stream;
  void add(GeoPoint point) {
    lastFix = LocationFix(
      position: point,
      accuracyM: 5,
      timestamp: DateTime(2026),
    );
    controller.add(lastFix!);
  }
}

class _Session implements SessionController {
  final controller = StreamController<SessionState>.broadcast();
  @override
  SessionState current = const SessionState.idle();
  @override
  Stream<SessionState> get state => controller.stream;
  @override
  Stream<PoiTriggerEvent> get triggers => const Stream.empty();
  @override
  Future<void> start(SessionMode mode) async {
    current = SessionState(mode: mode);
    controller.add(current);
  }

  @override
  Future<void> end() => start(SessionMode.none);
}
