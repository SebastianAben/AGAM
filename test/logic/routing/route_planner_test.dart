import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/data/poi_codec.dart';
import 'package:agam/logic/map/agam_map_config.dart';
import 'package:agam/logic/routing/campus_routing_service.dart';
import 'package:agam/logic/routing/device_navigation_controller.dart';
import 'package:agam/logic/routing/route_planner.dart';
import 'package:flutter_test/flutter_test.dart';

// SYNTHETIC geometry at the equator. 0.0001° is approximately 11.1195 m.
const start = GeoPoint(0, 0);
const corner = GeoPoint(0, .001);
const north = GeoPoint(.001, .001);
const west = GeoPoint(.001, 0);

/// SYNTHETIC position 44.48 m south of the start–corner path, beyond the
/// 25 m snap limit.
const inside = GeoPoint(-.0004, .0009);

/// SYNTHETIC door on that path, straight north of [inside] (44.48 m).
const door = GeoPoint(0, .0009);

const toNorth = NavigationTarget(
  id: 'synthetic-north',
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

Poi syntheticPoi(GeoPoint position, List<GeoPoint> doors) => Poi(
  id: 'P-SYNTHETIC',
  name: 'SINTETIS',
  aliases: const [],
  category: PoiCategory.lecture,
  position: position,
  radiusM: 15,
  entrances: [
    for (final (i, point) in doors.indexed)
      PoiEntrance(position: point, label: 'SINTETIS ${i + 1}'),
  ],
  description: 'SINTETIS',
  function: 'SINTETIS',
  facilities: const [],
  trivia: 'SINTETIS',
  media: const PoiMedia(),
  metadata: const ContentMetadata.placeholder(),
);

void main() {
  group('bundled assets: Labtek V to Labtek VII', () {
    final routing = CampusRoutingService.fromGeoJson(
      File('assets/routing/ganesha-walk-demo.geojson').readAsStringSync(),
      passages: File('assets/routing/passages.geojson').readAsStringSync(),
    );
    final pois = decodePoiDataset(
      jsonDecode(File('assets/data/pois.json').readAsStringSync()),
    ).pois;
    Poi poi(String id) => pois.firstWhere((p) => p.id == id);
    GeoPoint entrance(String id, String label) =>
        poi(id).entrances.firstWhere((e) => e.label == label).position;
    // Labtek V centre as given for the field report (lat, lng).
    const from = GeoPoint(-6.8905811, 107.6097754);
    final target = NavigationTarget.poi(poi('P03'));

    // Expected values come from an independent Python script (python3 -I,
    // own haversine R = 6371 km, own segment projection, own Dijkstra with
    // heapq) reading the same GeoJSON and pois.json:
    // - plain snap (west corridor, 14.7 m) → best Labtek VII door "barat":
    //   14.7 + 227.7 + 10.8 = 253.2 m (the reported detour);
    // - via Labtek V "Titik akses sisi timur 1": straight 53.1 m + snap
    //   7.6 m + graph 32.3 m + snap 10.8 m to Labtek VII "barat" = 103.8 m.
    //   Every other Labtek V door gives ≥ 124.7 m.
    test('without POIs the start snaps to the west corridor', () async {
      final route = await planWalkingRoute(
        routing: routing,
        from: from,
        target: target,
      );
      expect(route.distanceM, closeTo(253.2, 1));
    });

    test('a start inside Labtek V leaves by the east door', () async {
      final route = await planWalkingRoute(
        routing: routing,
        from: from,
        target: target,
        pois: pois,
      );
      expect(route.distanceM, closeTo(103.8, 1));
      expect(route.distanceM, lessThan(253.2 / 2));
      expect(route.path.first, from);
      expect(route.path[1], entrance('P01', 'Titik akses sisi timur 1'));
      expect(route.path.last, entrance('P03', 'Titik akses sisi barat'));
      // The walk stays east of the Labtek V centre (no west corridor).
      expect(route.path.skip(1).every((p) => p.lng > from.lng), isTrue);
      expect(route.steps.first.maneuver, Maneuver.depart);
      expect(route.steps.first.position, from);
      expect(route.steps.first.distanceM, closeTo(53.1, .5));
      expect(route.steps.last.maneuver, Maneuver.arrive);
      expect(
        route.steps.where((s) => s.maneuver == Maneuver.depart),
        hasLength(1),
      );
      final stepTotal = route.steps.fold(0.0, (sum, s) => sum + s.distanceM);
      expect(stepTotal, closeTo(route.distanceM, .01));
      expect(route.eta, CampusRoutingService.walkingTime(route.distanceM));
    });

    test('POIs that do not contain the start change nothing', () async {
      final route = await planWalkingRoute(
        routing: routing,
        from: from,
        target: target,
        pois: [poi('P03'), poi('P08')],
      );
      expect(route.distanceM, closeTo(253.2, 1));
    });
  });

  group('synthetic graph', () {
    final routing = CampusRoutingService.fromGeoJson(
      graph([
        [start, corner, north],
      ]),
    );

    test('a start beyond 25 m without a usable door is off-network', () async {
      await expectLater(
        planWalkingRoute(routing: routing, from: inside, target: toNorth),
        throwsA(isA<RouteStartOffNetworkException>()),
      );
      // The door of a POI that does not contain the start is ignored.
      await expectLater(
        planWalkingRoute(
          routing: routing,
          from: inside,
          target: toNorth,
          pois: [
            syntheticPoi(const GeoPoint(-.002, 0), [door]),
          ],
        ),
        throwsA(isA<RouteStartOffNetworkException>()),
      );
      // A door that is itself off the network does not help either.
      await expectLater(
        planWalkingRoute(
          routing: routing,
          from: inside,
          target: toNorth,
          pois: [
            syntheticPoi(inside, [const GeoPoint(-.0008, .0009)]),
          ],
        ),
        throwsA(isA<RouteStartOffNetworkException>()),
      );
    });

    test('a door of the POI around the start makes it routable', () async {
      final route = await planWalkingRoute(
        routing: routing,
        from: inside,
        target: toNorth,
        pois: [
          syntheticPoi(inside, [door]),
        ],
      );
      // 44.48 (inside→door) + 11.12 (door→corner) + 111.19 (corner→north).
      expect(route.distanceM, closeTo(166.79, .1));
      expect(route.path, [inside, door, corner, north]);
      expect(route.steps.map((s) => s.maneuver), [
        Maneuver.depart,
        Maneuver.turnRight, // heading north, then east along the path
        Maneuver.turnLeft,
        Maneuver.arrive,
      ]);
    });

    test('a start inside the hull of the doors counts as inside', () async {
      // SYNTHETIC POI whose centre is 55.6 m away (radius 15 m) but whose
      // doors surround the start.
      final route = await planWalkingRoute(
        routing: routing,
        from: inside,
        target: toNorth,
        pois: [
          syntheticPoi(const GeoPoint(-.0004, .0004), [
            door,
            const GeoPoint(0, .0001),
            const GeoPoint(-.0008, .0001),
            const GeoPoint(-.0008, .0010),
          ]),
        ],
      );
      expect(route.path.take(2), [inside, door]);
      expect(route.distanceM, closeTo(166.79, .1));
    });

    test('an off-network destination is not reported as the start', () async {
      const remote = NavigationTarget(
        id: 'synthetic-remote',
        name: 'Tujuan sintetis',
        kind: NavigationTargetKind.poi,
        point: GeoPoint(.005, .005),
        isPlaceholderPoint: false,
      );
      await expectLater(
        planWalkingRoute(routing: routing, from: start, target: remote),
        throwsA(
          isA<RouteUnavailableException>().having(
            (e) => e,
            'kind',
            isNot(isA<RouteStartOffNetworkException>()),
          ),
        ),
      );
      // Off-network start rescued by a door, but the destination is remote:
      // the failure belongs to the destination, not the start.
      await expectLater(
        planWalkingRoute(
          routing: routing,
          from: inside,
          target: remote,
          pois: [
            syntheticPoi(inside, [door]),
          ],
        ),
        throwsA(
          isA<RouteUnavailableException>().having(
            (e) => e,
            'kind',
            isNot(isA<RouteStartOffNetworkException>()),
          ),
        ),
      );
    });

    test('the plain snap still wins when it is shorter', () async {
      // Start 5.6 m from the path; its own door is 44.5 m away.
      const near = GeoPoint(-.00005, .0005);
      final route = await planWalkingRoute(
        routing: routing,
        from: near,
        target: toNorth,
        pois: [
          syntheticPoi(near, [const GeoPoint(-.0004, .0005)]),
        ],
      );
      expect(route.path.take(2), [near, const GeoPoint(0, .0005)]);
      // 5.56 + 55.6 + 111.19.
      expect(route.distanceM, closeTo(172.35, .1));
    });
  });

  test(
    'navigation from inside a POI reroutes off the door leg and arrives',
    () async {
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
      final location = _Location();
      final session = _Session();
      final controller = DeviceNavigationController(
        location: location,
        routing: CampusRoutingService.fromGeoJson(
          graph([
            [start, corner, north],
            [start, west, north],
          ]),
        ),
        map: map,
        session: session,
        pois: () => [
          syntheticPoi(inside, [door]),
        ],
      );
      addTearDown(location.controller.close);
      addTearDown(session.controller.close);
      addTearDown(controller.stop);
      await session.start(SessionMode.navigation);
      location.add(inside);
      await controller.start(toNorth);
      expect(controller.current.status, NavigationStatus.onRoute);
      expect(controller.current.route!.path, [inside, door, corner, north]);
      expect(controller.current.remainingDistanceM, closeTo(166.79, .1));

      // Walking the indoor leg toward the door stays on route.
      location.add(const GeoPoint(-.0002, .0009));
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.status, NavigationStatus.onRoute);
      expect(controller.current.remainingDistanceM, closeTo(144.55, .1));

      // 55.6 m off the route, on the west path: reroute from the new fix.
      location.add(const GeoPoint(.0005, 0));
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.status, NavigationStatus.onRoute);
      expect(controller.current.route!.path, [
        const GeoPoint(.0005, 0),
        west,
        north,
      ]);

      location.add(const GeoPoint(.001, .00086)); // 15.57 m.
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.status, NavigationStatus.onRoute);
      location.add(const GeoPoint(.001, .00087)); // 14.46 m.
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.status, NavigationStatus.arrived);
    },
  );

  test('navigation without POIs reports an off-network start', () async {
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
    final location = _Location();
    final session = _Session();
    final controller = DeviceNavigationController(
      location: location,
      routing: CampusRoutingService.fromGeoJson(
        graph([
          [start, corner, north],
        ]),
      ),
      map: map,
      session: session,
    );
    addTearDown(location.controller.close);
    addTearDown(session.controller.close);
    addTearDown(controller.stop);
    await session.start(SessionMode.navigation);
    location.add(inside);
    await controller.start(toNorth);
    expect(controller.current.status, NavigationStatus.error);
  });
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
