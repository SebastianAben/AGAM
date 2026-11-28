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

  test('snaps only to the main network, never to an isolated piece', () async {
    // The short piece is 5.6 m from the destination, the main path 16.7 m.
    const destination = GeoPoint(.00015, .0005);
    final routing = CampusRoutingService.fromGeoJson(
      graph([
        [start, corner],
        [const GeoPoint(.0002, .0005), const GeoPoint(.0002, .0006)],
      ]),
    );
    final route = await routing.route(from: start, to: destination);
    expect(route.path, [start, const GeoPoint(0, .0005), destination]);
    expect(route.distanceM, closeTo(55.6 + 16.68, .1));
  });

  test('passages join new access points and are named in the steps', () async {
    const door = GeoPoint(.0002, .001); // 22.24 m north of the corner.
    String passage({required bool verified}) => jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {'id': 'SYNTHETIC', 'verified': verified},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [corner.lng, corner.lat],
              [door.lng, door.lat],
            ],
          },
        },
      ],
    });
    for (final verified in [false, true]) {
      final routing = CampusRoutingService.fromGeoJson(
        graph([
          [start, corner],
        ]),
        passages: passage(verified: verified),
      );
      final route = await routing.route(from: start, to: door);
      expect(route.path, [start, corner, door]);
      expect(route.steps[1].maneuver, Maneuver.turnLeft);
      expect(
        route.steps[1].instruction,
        verified
            ? 'Belok kiri, lewat lorong dalam gedung.'
            : 'Belok kiri, lewat lorong dalam gedung (belum diverifikasi).',
      );
    }
  });

  group('access point candidates', () {
    // B is 222.4 m east along the path; A is only 55.6 m north in a straight
    // line but 500.4 m away on foot.
    const a = GeoPoint(.0005, 0);
    const b = GeoPoint(0, .002);
    const candidates = NavigationTarget(
      id: 'synthetic-building',
      name: 'Gedung sintetis',
      kind: NavigationTargetKind.poi,
      point: a,
      isPlaceholderPoint: true,
      candidates: [a, b],
    );
    late _Location location;
    late _Session session;
    late _CountingRouting routing;
    late DeviceNavigationController controller;

    setUp(() async {
      location = _Location();
      session = _Session();
      routing = _CountingRouting(
        CampusRoutingService.fromGeoJson(
          graph([
            [start, b],
            [b, const GeoPoint(.0005, .002), a],
          ]),
        ),
      );
      controller = DeviceNavigationController(
        location: location,
        routing: routing,
        map: map,
        session: session,
      );
      await session.start(SessionMode.navigation);
      location.add(start);
      await controller.start(candidates);
    });

    tearDown(() async {
      await controller.stop();
      await location.controller.close();
      await session.controller.close();
    });

    test('routes to the shortest walk, not the nearest straight line', () {
      expect(routing.calls, 2);
      final route = controller.current.route!;
      expect(controller.current.status, NavigationStatus.onRoute);
      expect(route.path.last, b);
      expect(route.distanceM, closeTo(222.39, .1));
    });

    test('reroutes to the access point that is now nearest on foot', () async {
      location.add(const GeoPoint(.0005, .001)); // 55.6 m off the route.
      await Future<void>.delayed(Duration.zero);
      expect(routing.calls, 4);
      expect(controller.current.status, NavigationStatus.onRoute);
      expect(controller.current.route!.path.last, a);
      expect(controller.current.route!.distanceM, closeTo(111.2, .1));
    });

    test(
      'arrives within 15 m of any candidate, not only the routed one',
      () async {
        location.add(const GeoPoint(.0004, .00001)); // 11.2 m from A.
        await Future<void>.delayed(Duration.zero);
        expect(controller.current.status, NavigationStatus.arrived);
        expect(controller.current.route!.path.last, b);
      },
    );
  });

  test('targets keep the contract for facilities and POI access points', () {
    const metadata = ContentMetadata.placeholder();
    final facility = NavigationTarget.facility(
      const Facility(
        id: 'F-SYNTHETIC',
        name: 'Toilet sintetis',
        category: FacilityCategory.toilet,
        position: corner,
        description: 'SINTETIS',
        metadata: metadata,
      ),
    );
    expect(facility.point, corner);
    expect(facility.candidates, isEmpty);
    expect(facility.isPlaceholderPoint, isFalse);

    Poi poi(List<PoiEntrance> entrances) => Poi(
      id: 'P-SYNTHETIC',
      name: 'SINTETIS',
      aliases: const [],
      category: PoiCategory.lecture,
      position: start,
      radiusM: 15,
      entrances: entrances,
      description: 'SINTETIS',
      function: 'SINTETIS',
      facilities: const [],
      trivia: 'SINTETIS',
      media: const PoiMedia(),
      metadata: metadata,
    );
    final withEntrances = NavigationTarget.poi(
      poi(const [
        PoiEntrance(position: corner, label: 'SINTETIS 1'),
        PoiEntrance(position: north, label: 'SINTETIS 2'),
      ]),
    );
    expect(withEntrances.point, corner);
    expect(withEntrances.candidates, [corner, north]);
    expect(withEntrances.isPlaceholderPoint, isTrue);
    final centre = NavigationTarget.poi(poi(const []));
    expect(centre.point, start);
    expect(centre.candidates, isEmpty);
  });

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

  group('step progression regressions (B05)', () {
    test(
      'short depart leg <= 10 m is shown at start before advancing to the turn',
      () async {
        // SYNTHETIC: 8.0 m east to corner, then 111.2 m north.
        const shortStart = GeoPoint(0, .000928);
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
        location.add(shortStart);
        await controller.start(target);
        expect(controller.current.status, NavigationStatus.onRoute);
        expect(controller.current.route!.steps[0].distanceM, closeTo(8.0, 0.2));
        expect(controller.current.currentStepIndex, 0);
        expect(controller.current.currentStep!.maneuver, Maneuver.depart);

        // Move 2.2 m along the 8 m depart leg: still departing.
        location.add(const GeoPoint(0, .000948));
        await Future<void>.delayed(Duration.zero);
        expect(controller.current.currentStepIndex, 0);
        expect(controller.current.currentStep!.maneuver, Maneuver.depart);

        // Move 5.0 m along the 8 m leg (3 m before corner): announces turnLeft.
        location.add(const GeoPoint(0, .000973));
        await Future<void>.delayed(Duration.zero);
        expect(controller.current.currentStepIndex, 1);
        expect(controller.current.currentStep!.maneuver, Maneuver.turnLeft);
      },
    );

    test('after passing a turn on a long straight leg, instruction transitions to straight and announces next turn without flicker', () async {
      // SYNTHETIC:
      // p0=(0,0) -> p1=(0, .0005) [55.6 m]
      //          -> p2=(.0008, .0005) [89.0 m, turnLeft at 55.6 m]
      //          -> p3=(.0008, .0011) [66.7 m, turnRight at 144.6 m]
      const p0 = GeoPoint(0, 0);
      const p1 = GeoPoint(0, .0005);
      const p2 = GeoPoint(.0008, .0005);
      const p3 = GeoPoint(.0008, .0011);
      const endTarget = NavigationTarget(
        id: 'synthetic-3leg',
        name: 'Tujuan 3 ruas sintetis',
        kind: NavigationTargetKind.poi,
        point: p3,
        isPlaceholderPoint: false,
      );
      final location = _Location();
      final session = _Session();
      final controller = DeviceNavigationController(
        location: location,
        routing: CampusRoutingService.fromGeoJson(
          graph([
            [p0, p1, p2, p3],
          ]),
        ),
        map: map,
        session: session,
      );
      addTearDown(location.controller.close);
      addTearDown(session.controller.close);
      addTearDown(controller.stop);

      await session.start(SessionMode.navigation);
      location.add(p0);
      await controller.start(endTarget);
      expect(controller.current.currentStepIndex, 0);
      expect(controller.current.currentStep!.maneuver, Maneuver.depart);

      // 47.8 m along leg 0 (7.8 m before p1): announces turnLeft.
      location.add(const GeoPoint(0, .00043));
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.currentStepIndex, 1);
      expect(controller.current.currentStep!.maneuver, Maneuver.turnLeft);

      // 5.6 m past p1: still executing turnLeft.
      location.add(const GeoPoint(.00005, .0005));
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.currentStepIndex, 1);
      expect(controller.current.currentStep!.maneuver, Maneuver.turnLeft);

      // 16.7 m past p1 (72.3 m before p2): transitions to Lanjut lurus.
      location.add(const GeoPoint(.00015, .0005));
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.currentStepIndex, 1);
      expect(controller.current.currentStep!.maneuver, Maneuver.straight);
      expect(controller.current.currentStep!.instruction, 'Lanjut lurus.');

      // 12.2 m before p2: stays Lanjut lurus. (no flicker back to turnLeft).
      location.add(const GeoPoint(.00069, .0005));
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.currentStepIndex, 1);
      expect(controller.current.currentStep!.maneuver, Maneuver.straight);

      // 8.9 m before p2: advances cleanly to turnRight.
      location.add(const GeoPoint(.00072, .0005));
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.currentStepIndex, 2);
      expect(controller.current.currentStep!.maneuver, Maneuver.turnRight);
    });
  });

  test('indoor facility routed via building entrances arrives within 15 m of entrance (B08)', () async {
    // SYNTHETIC: building centre is 55.6 m north of start, doors A & B sit
    // on the walking graph.
    const buildingCenter = GeoPoint(.0005, .0005);
    const entranceA = GeoPoint(0, .0005);
    const entranceB = GeoPoint(.001, .0005);
    const meta = ContentMetadata(
      sources: ['SINTETIS'],
      verifiedAt: null,
      owner: 'SINTETIS',
      assetAttribution: [],
      approved: true,
    );
    const building = Poi(
      id: 'P-SYN-BLD',
      name: 'Gedung SINTETIS',
      aliases: [],
      category: PoiCategory.lecture,
      position: buildingCenter,
      radiusM: 15,
      entrances: [
        PoiEntrance(position: entranceA, label: 'Pintu selatan'),
        PoiEntrance(position: entranceB, label: 'Pintu utara'),
      ],
      description: 'SINTETIS',
      function: 'SINTETIS',
      facilities: ['Toilet'],
      trivia: 'SINTETIS',
      media: PoiMedia(),
      metadata: meta,
    );
    const indoorFacility = Facility(
      id: 'F-SYN-TOILET',
      name: 'Toilet Gedung SINTETIS',
      category: FacilityCategory.toilet,
      position: buildingCenter,
      buildingId: 'P-SYN-BLD',
      description: 'Gedung SINTETIS, lantai 2. Titik peta memakai titik gedung; letak persis di dalam gedung belum disurvei.',
      metadata: meta,
    );
    final facilityTarget = NavigationTarget.facility(
      indoorFacility,
      building: building,
    );
    expect(facilityTarget.candidates, [entranceA, entranceB]);
    expect(facilityTarget.locationHint, 'Gedung SINTETIS, lantai 2');

    final location = _Location();
    final session = _Session();
    final controller = DeviceNavigationController(
      location: location,
      routing: CampusRoutingService.fromGeoJson(
        graph([
          [start, entranceA, corner, north, entranceB],
        ]),
      ),
      map: map,
      session: session,
    );
    addTearDown(location.controller.close);
    addTearDown(session.controller.close);
    addTearDown(controller.stop);

    await session.start(SessionMode.navigation);
    location.add(start);
    await controller.start(facilityTarget);
    expect(controller.current.status, NavigationStatus.onRoute);
    expect(controller.current.route!.path.last, entranceA);

    // 11.1 m from entranceA (>50 m from buildingCenter): arrives <= 15 m.
    location.add(const GeoPoint(0, .0004));
    await Future<void>.delayed(Duration.zero);
    expect(controller.current.status, NavigationStatus.arrived);
  });

  group('reroute failure stability (B09)', () {
    test('repeated fixes at the same off-network spot do not loop calculating/error and recover when returning to route', () async {
      final location = _Location();
      final session = _Session();
      final routing = _CountingRouting(
        CampusRoutingService.fromGeoJson(
          graph([
            [start, corner, north],
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
      final listener = controller.state.listen((s) => seen.add(s.status));
      addTearDown(listener.cancel);
      addTearDown(location.controller.close);
      addTearDown(session.controller.close);
      addTearDown(controller.stop);

      await session.start(SessionMode.navigation);
      location.add(start);
      await controller.start(target);
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.status, NavigationStatus.onRoute);
      expect(routing.calls, 1);

      // Off-route AND off-network (44.5 m south of start-corner path).
      const offNetwork = GeoPoint(-.0004, .0005);
      seen.clear();
      location.add(offNetwork);
      await Future<void>.delayed(Duration.zero);
      expect(routing.calls, 2);
      expect(seen, [
        NavigationStatus.offRoute,
        NavigationStatus.rerouting,
        NavigationStatus.error,
      ]);
      expect(controller.current.route, isNotNull);

      // Repeated fixes at same spot and 4.4 m away (< 10 m): no spam, no reroute.
      seen.clear();
      location.add(offNetwork);
      await Future<void>.delayed(Duration.zero);
      location.add(const GeoPoint(-.0004, .00054));
      await Future<void>.delayed(Duration.zero);
      location.add(const GeoPoint(-.00042, .00052));
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty);
      expect(routing.calls, 2);
      expect(controller.current.status, NavigationStatus.error);

      // Returning within <= 25 m of the preserved route resumes onRoute directly.
      location.add(const GeoPoint(-.0001, .0005)); // 11.1 m from route.
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.status, NavigationStatus.onRoute);
      expect(routing.calls, 2);
    });

    test(
      'reroute retries once the walker moves >= 10 m from a failed spot',
      () async {
        final location = _Location();
        final session = _Session();
        final routing = _CountingRouting(
          CampusRoutingService.fromGeoJson(
            graph([
              [start, corner, north],
              [const GeoPoint(-.0006, 0), const GeoPoint(-.0006, .001), corner],
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
        final listener = controller.state.listen((s) => seen.add(s.status));
        addTearDown(listener.cancel);
        addTearDown(location.controller.close);
        addTearDown(session.controller.close);
        addTearDown(controller.stop);

        await session.start(SessionMode.navigation);
        location.add(start);
        await controller.start(target);
        expect(routing.calls, 1);

        // Halfway between y=0 and y=-0.0006: 33.4 m from both paths (off-network).
        location.add(const GeoPoint(-.0003, .0005));
        await Future<void>.delayed(Duration.zero);
        expect(controller.current.status, NavigationStatus.error);
        expect(routing.calls, 2);

        // Move 16.7 m south to y=-0.00045 (16.7 m from lower path): retries and succeeds.
        seen.clear();
        location.add(const GeoPoint(-.00045, .0005));
        await Future<void>.delayed(Duration.zero);
        expect(routing.calls, 3);
        expect(seen, [NavigationStatus.rerouting, NavigationStatus.onRoute]);
        expect(controller.current.status, NavigationStatus.onRoute);
      },
    );

    test('initial route calculation failure does not spam calculating/error on repeated fixes', () async {
      final location = _Location();
      final session = _Session();
      final routing = _CountingRouting(
        CampusRoutingService.fromGeoJson(
          graph([
            [start, corner, north],
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
      final listener = controller.state.listen((s) => seen.add(s.status));
      addTearDown(listener.cancel);
      addTearDown(location.controller.close);
      addTearDown(session.controller.close);
      addTearDown(controller.stop);

      const offNetwork = GeoPoint(-.0004, .0005);
      await session.start(SessionMode.navigation);
      location.add(offNetwork);
      await controller.start(target);
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.status, NavigationStatus.error);
      expect(routing.calls, 1);

      seen.clear();
      location.add(offNetwork);
      await Future<void>.delayed(Duration.zero);
      location.add(const GeoPoint(-.0004, .00053));
      await Future<void>.delayed(Duration.zero);
      expect(seen, isEmpty);
      expect(routing.calls, 1);

      // Move >= 10 m onto the network: retries and enters onRoute.
      location.add(const GeoPoint(0, .0005));
      await Future<void>.delayed(Duration.zero);
      expect(controller.current.status, NavigationStatus.onRoute);
      expect(routing.calls, 2);
    });
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
