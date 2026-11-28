import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/contracts/fakes/fake_lb_services.dart';
import 'package:agam/logic/routing/campus_routing_service.dart';
import 'package:agam/logic/routing/device_navigation_controller.dart';
import 'package:agam/logic/trail/account_visit_store.dart';
import 'package:agam/logic/trail/device_trail_service.dart';
import 'package:agam/logic/trail/trail_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'synthetic_trail.dart';

/// Spy [NavigationController] untuk menghitung pemanggilan `start()` dan
/// mensimulasikan status navigasi secara langsung.
class _SpyNavigationController implements NavigationController {
  final _states = StreamController<NavigationState>.broadcast();
  NavigationState _current = const NavigationState.idle();
  final startedTargets = <NavigationTarget>[];

  @override
  NavigationState get current => _current;

  @override
  Stream<NavigationState> get state => _states.stream;

  @override
  Future<void> start(NavigationTarget target) async {
    startedTargets.add(target);
    emit(NavigationState(status: NavigationStatus.onRoute, target: target));
  }

  @override
  Future<void> stop() async {
    emit(const NavigationState.idle());
  }

  void emit(NavigationState next) {
    _current = next;
    _states.add(next);
  }

  Future<void> dispose() => _states.close();
}

class _FailingVisitStore extends AccountVisitStore {
  bool failSaveTrail = false;
  bool failReadTrail = false;
  Completer<void>? saveGate;

  @override
  Future<({Set<String> ids, DateTime? date})> readTrail(String uid) async {
    if (failReadTrail) throw StateError('synthetic read failure');
    return super.readTrail(uid);
  }

  @override
  Future<void> saveTrail(String uid, Set<String> ids, DateTime? date) async {
    if (saveGate != null) await saveGate!.future;
    if (failSaveTrail) throw StateError('synthetic save failure');
    return super.saveTrail(uid, ids, date);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'B01: arrival <=15m at an access point >20m from building center checks in '
    'and preserves ArrivalCard without auto-routing',
    () async {
      // Synthetic POI-0 has its center 35 m north of the walkable path, while
      // its access point sits on the path (mimicking 33/41 real entrances >20m
      // from center).
      final farCenterPois = [
        for (var i = 0; i < 10; i++)
          Poi(
            id: 'synthetic-$i',
            name: 'POI Sintetis $i',
            aliases: const [],
            category: PoiCategory.lecture,
            position: i == 0
                ? const GeoPoint(-6.88968, 107.608)
                : GeoPoint(-6.89, 107.608 + i * .0005),
            radiusM: 15,
            entrances: [
              PoiEntrance(
                position: GeoPoint(-6.89, 107.608 + i * .0005),
                label: 'Pintu sintetis',
                verified: false,
              ),
            ],
            description: '',
            function: '',
            facilities: const [],
            trivia: '',
            media: const PoiMedia(),
            metadata: const ContentMetadata.placeholder(),
            trailOrder: i + 1,
          ),
      ];
      expect(
        farCenterPois[0].position.distanceTo(
          farCenterPois[0].entrances.first.position,
        ),
        greaterThan(20),
      );

      final location = SyntheticLocation()
        ..move(const GeoPoint(-6.89, 107.6075));
      final session = SyntheticSession();
      final map = FakeMapConfig(pois: farCenterPois);
      final navigation = DeviceNavigationController(
        location: location,
        session: session,
        map: map,
        routing: CampusRoutingService.fromGeoJson(syntheticGraph),
      );
      final activity = FakeActivityLogger();
      final trail = createDeviceTrailService(
        pois: FakePoiRepository(pois: farCenterPois, facilities: const []),
        location: location,
        session: session,
        navigation: navigation,
        map: map,
        activity: activity,
        currentUid: () => 'synthetic-A',
        accounts: const Stream.empty(),
        routingAvailable: true,
        clock: () => DateTime(2026, 11, 28, 14, 35, 12),
      );
      addTearDown(() async {
        await trail.dispose();
        await navigation.stop();
        await session.dispose();
        await location.controller.close();
      });

      await pumpEventQueue();
      await trail.start();
      await session.start(SessionMode.trail);
      await pumpEventQueue();
      expect(navigation.current.status, NavigationStatus.onRoute);
      expect(navigation.current.target?.id, 'synthetic-0');
      expect(trail.current.visitedCount, 0);

      // Walk to 5 m from POI-0's access point (>30 m from building center, so
      // no geofence trigger fires).
      location.move(const GeoPoint(-6.89, 107.60795));
      await pumpEventQueue(times: 50);

      expect(navigation.current.status, NavigationStatus.arrived);
      expect(navigation.current.target?.id, 'synthetic-0');
      expect(trail.current.visited, {'synthetic-0'});
      expect(trail.current.visitedCount, 1);
      expect(trail.current.nextPoiId, 'synthetic-1');

      // ArrivalCard is preserved (not hijacked by auto-routing to synthetic-1).
      expect(navigation.current.status, NavigationStatus.arrived);
      expect(navigation.current.target?.id, 'synthetic-0');

      // An out-of-order geofence trigger while ArrivalCard is open still counts
      // progress without disturbing ArrivalCard.
      session.trigger(3);
      await pumpEventQueue(times: 50);
      expect(trail.current.visited, {'synthetic-0', 'synthetic-3'});
      expect(navigation.current.status, NavigationStatus.arrived);
      expect(navigation.current.target?.id, 'synthetic-0');
    },
  );

  test(
    'B01: arrival ignores facility targets and non-trail modes, deduplicates '
    'with triggers in both orders, and completes once with date-only clock',
    () async {
      final location = SyntheticLocation()
        ..move(const GeoPoint(-6.89, 107.6075));
      final session = SyntheticSession();
      final map = FakeMapConfig(pois: syntheticPois);
      final navigation = _SpyNavigationController();
      var completionCount = 0;
      final trail = DeviceTrailService(
        pois: FakePoiRepository(pois: syntheticPois, facilities: const []),
        location: location,
        visits: AccountVisitStore(),
        currentUid: () => 'synthetic-A',
        accounts: const Stream.empty(),
        session: session,
        navigation: navigation,
        map: map,
        routingAvailable: true,
        onComplete: () => completionCount++,
        clock: () => DateTime(2026, 11, 28, 16, 45, 59),
      );
      addTearDown(() async {
        await trail.dispose();
        await navigation.dispose();
        await session.dispose();
        await location.controller.close();
      });

      await pumpEventQueue();

      // Arrival during Navigation mode does not check in.
      await session.start(SessionMode.navigation);
      navigation.emit(
        NavigationState(
          status: NavigationStatus.arrived,
          target: NavigationTarget.poi(syntheticPois[0]),
        ),
      );
      await pumpEventQueue();
      expect(trail.current.visitedCount, 0);

      // Start Trail mode.
      await session.end();
      await navigation.stop();
      await trail.start();
      await session.start(SessionMode.trail);
      await pumpEventQueue();

      // Arrival at a facility does not check in.
      navigation.emit(
        NavigationState(
          status: NavigationStatus.arrived,
          target: NavigationTarget.facility(
            Facility(
              id: 'synthetic-0',
              name: 'Fasilitas Sintetis',
              category: FacilityCategory.toilet,
              position: syntheticPois[0].position,
              description: '',
              metadata: const ContentMetadata.placeholder(),
            ),
          ),
        ),
      );
      await pumpEventQueue();
      expect(trail.current.visitedCount, 0);

      // Order 1: arrival first, then geofence trigger for same POI -> once.
      navigation.emit(
        NavigationState(
          status: NavigationStatus.arrived,
          target: NavigationTarget.poi(syntheticPois[0]),
        ),
      );
      session.trigger(0);
      await pumpEventQueue(times: 30);
      expect(trail.current.visited, {'synthetic-0'});

      // Order 2: geofence trigger first (while onRoute), then arrival -> once.
      await navigation.start(NavigationTarget.poi(syntheticPois[1]));
      session.trigger(1);
      navigation.emit(
        NavigationState(
          status: NavigationStatus.arrived,
          target: NavigationTarget.poi(syntheticPois[1]),
        ),
      );
      await pumpEventQueue(times: 30);
      expect(trail.current.visited, {'synthetic-0', 'synthetic-1'});

      // Check in stops 2..8 via trigger.
      for (var i = 2; i < 9; i++) {
        session.trigger(i);
      }
      await pumpEventQueue(times: 60);
      expect(trail.current.visitedCount, 9);
      expect(completionCount, 0);

      // Complete 10th stop via NavigationStatus.arrived + duplicate trigger.
      navigation.emit(
        NavigationState(
          status: NavigationStatus.arrived,
          target: NavigationTarget.poi(syntheticPois[9]),
        ),
      );
      session.trigger(9);
      await pumpEventQueue(times: 60);

      expect(trail.current.visitedCount, 10);
      expect(trail.current.isComplete, isTrue);
      expect(trail.current.active, isFalse);
      // Date-only precision from injected clock (no time-of-day stored).
      expect(trail.current.completedAt, DateTime(2026, 11, 28));
      expect(completionCount, 1);
      expect(navigation.current.status, NavigationStatus.idle);
      expect(session.current.isActive, isFalse);
    },
  );

  test('B06: previewFirstStopId returns nearest stop without persisting and '
      'switches to nextPoiId after start', () async {
    final accounts = StreamController<Object?>.broadcast();
    String? uid = 'synthetic-A';
    final location = SyntheticLocation();
    final session = SyntheticSession();
    final map = FakeMapConfig(pois: unverifiedSyntheticPois);
    final navigation = _SpyNavigationController();
    final trail = DeviceTrailService(
      pois: FakePoiRepository(
        pois: unverifiedSyntheticPois,
        facilities: const [],
      ),
      location: location,
      visits: AccountVisitStore(),
      currentUid: () => uid,
      accounts: accounts.stream,
      session: session,
      navigation: navigation,
      map: map,
      routingAvailable: true,
      onComplete: () {},
    );
    addTearDown(() async {
      await trail.dispose();
      await navigation.dispose();
      await session.dispose();
      await accounts.close();
      await location.controller.close();
    });

    // Before POI stream emits, preview returns null safely.
    expect(trail.previewFirstStopId(), isNull);

    await pumpEventQueue();
    // No fix yet -> official first stop, without persisting start.
    expect(trail.previewFirstStopId(), 'synthetic-0');
    // Explicit position near stop 6 -> synthetic-6, without persisting start.
    expect(
      trail.previewFirstStopId(
        GeoPoint(-6.88995, unverifiedSyntheticPois[6].position.lng),
      ),
      'synthetic-6',
    );
    // Uses location.lastFix when no position argument is passed.
    location.move(GeoPoint(-6.88995, unverifiedSyntheticPois[3].position.lng));
    expect(trail.previewFirstStopId(), 'synthetic-3');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('account.synthetic-A.trailStart'), isNull);

    // After start(), start is persisted (synthetic-3) and preview follows
    // nextPoiId even if user moves elsewhere.
    await trail.start();
    await session.start(SessionMode.trail);
    await pumpEventQueue();
    expect(trail.previewFirstStopId(), 'synthetic-3');
    expect(
      trail.previewFirstStopId(
        GeoPoint(-6.88995, unverifiedSyntheticPois[8].position.lng),
      ),
      'synthetic-3',
    );

    session.trigger(3);
    await pumpEventQueue();
    expect(trail.previewFirstStopId(), 'synthetic-4');

    // Account switch before _restore completes does not leak previous start.
    uid = 'synthetic-B';
    expect(
      trail.previewFirstStopId(
        GeoPoint(-6.88995, unverifiedSyntheticPois[8].position.lng),
      ),
      'synthetic-8',
    );
    accounts.add(null);
    await pumpEventQueue();
    uid = 'synthetic-A';
    accounts.add(null);
    await pumpEventQueue();

    // After reset(), start is cleared and preview computes nearest again.
    await trail.reset();
    location.move(GeoPoint(-6.88995, unverifiedSyntheticPois[9].position.lng));
    expect(trail.previewFirstStopId(), 'synthetic-9');
  });

  test(
    'B06 & B12: _routeNext does not hijack manual unvisited trail target, '
    'avoids redundant start(), and out-of-order triggers keep current route',
    () async {
      final location = SyntheticLocation()
        ..move(const GeoPoint(-6.89, 107.6075));
      final session = SyntheticSession();
      final map = FakeMapConfig(pois: syntheticPois);
      final navigation = _SpyNavigationController();
      final trail = DeviceTrailService(
        pois: FakePoiRepository(pois: syntheticPois, facilities: const []),
        location: location,
        visits: AccountVisitStore(),
        currentUid: () => 'synthetic-A',
        accounts: const Stream.empty(),
        session: session,
        navigation: navigation,
        map: map,
        routingAvailable: true,
        onComplete: () {},
      );
      addTearDown(() async {
        await trail.dispose();
        await navigation.dispose();
        await session.dispose();
        await location.controller.close();
      });

      await pumpEventQueue();
      await trail.start();

      // User explicitly starts navigation to an unvisited Trail POI (stop 4)
      // while nextPoiId is stop 0.
      await navigation.start(NavigationTarget.poi(syntheticPois[4]));
      expect(navigation.startedTargets.map((t) => t.id), ['synthetic-4']);

      // Session enters trail mode -> _routeNext must NOT hijack stop 4!
      await session.start(SessionMode.trail);
      await pumpEventQueue();
      expect(navigation.current.target?.id, 'synthetic-4');
      expect(navigation.startedTargets.map((t) => t.id), ['synthetic-4']);

      // Re-emitting SessionMode.trail must NOT trigger redundant start().
      await session.start(SessionMode.trail);
      await pumpEventQueue();
      expect(navigation.startedTargets.map((t) => t.id), ['synthetic-4']);

      // Out-of-order trigger for stop 0 (even though it was nextPoiId!) must
      // NOT disturb the ongoing route to stop 4.
      session.trigger(0);
      await pumpEventQueue();
      expect(trail.current.visited, {'synthetic-0'});
      expect(trail.current.nextPoiId, 'synthetic-1');
      expect(navigation.current.target?.id, 'synthetic-4');
      expect(navigation.startedTargets.map((t) => t.id), ['synthetic-4']);

      // Triggering the active target (stop 4) while onRoute advances to
      // nextPoiId (stop 1).
      session.trigger(4);
      await pumpEventQueue();
      expect(trail.current.visited, {'synthetic-0', 'synthetic-4'});
      expect(navigation.current.target?.id, 'synthetic-1');
      expect(navigation.startedTargets.map((t) => t.id), [
        'synthetic-4',
        'synthetic-1',
      ]);

      // Re-emitting SessionMode.trail while already onRoute to nextPoiId
      // avoids redundant start().
      await session.start(SessionMode.trail);
      await pumpEventQueue();
      expect(navigation.startedTargets.map((t) => t.id), [
        'synthetic-4',
        'synthetic-1',
      ]);

      // If navigation transitions to error, _routeNext retries start().
      navigation.emit(
        NavigationState(
          status: NavigationStatus.error,
          target: NavigationTarget.poi(syntheticPois[1]),
        ),
      );
      await session.start(SessionMode.trail);
      await pumpEventQueue();
      expect(navigation.startedTargets.map((t) => t.id), [
        'synthetic-4',
        'synthetic-1',
        'synthetic-1',
      ]);
    },
  );

  test('B24: _background suppresses uncaught errors without listeners or after '
      'dispose, and forwards errors to listeners with onError', () async {
    final uncaught = <Object>[];
    await runZonedGuarded(() async {
      final location = SyntheticLocation()
        ..move(const GeoPoint(-6.89, 107.6075));
      final session = SyntheticSession();
      final map = FakeMapConfig(pois: syntheticPois);
      final navigation = _SpyNavigationController();
      final visits = _FailingVisitStore();
      final trail = DeviceTrailService(
        pois: FakePoiRepository(pois: syntheticPois, facilities: const []),
        location: location,
        visits: visits,
        currentUid: () => 'synthetic-A',
        accounts: const Stream.empty(),
        session: session,
        navigation: navigation,
        map: map,
        routingAvailable: true,
        onComplete: () {},
      );
      addTearDown(() async {
        await trail.dispose();
        await navigation.dispose();
        await session.dispose();
        await location.controller.close();
      });

      await pumpEventQueue();
      await trail.start();
      await session.start(SessionMode.trail);
      await pumpEventQueue();

      // 1. Failing background save with NO listener on trail.progress:
      //    must NOT throw an uncaught async zone error.
      visits.failSaveTrail = true;
      session.trigger(0);
      await pumpEventQueue(times: 30);
      expect(uncaught, isEmpty);

      // 2. With a listener providing onError: error IS propagated.
      final observed = <Object>[];
      final sub = trail.progress.listen((_) {}, onError: observed.add);
      session.trigger(1);
      await pumpEventQueue(times: 30);
      expect(observed, hasLength(1));
      expect(observed.single, isA<StateError>());
      await sub.cancel();

      // 3. Failing background task completing during dispose() must NOT
      //    throw StateError("Cannot add event after closing").
      final gate = Completer<void>();
      visits.saveGate = gate;
      session.trigger(2);
      await pumpEventQueue();
      final disposing = trail.dispose();
      gate.complete();
      await disposing;
      await pumpEventQueue(times: 30);
      expect(uncaught, isEmpty);
    }, (error, _) => uncaught.add(error));
    expect(uncaught, isEmpty);
  });
}
