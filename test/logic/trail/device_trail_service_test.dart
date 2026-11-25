import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/contracts/fakes/fake_lb_services.dart';
import 'package:agam/logic/routing/campus_routing_service.dart';
import 'package:agam/logic/routing/device_navigation_controller.dart';
import 'package:agam/logic/search/repository_facility_service.dart';
import 'package:agam/logic/search/repository_recommendation_service.dart';
import 'package:agam/logic/trail/account_visit_store.dart';
import 'package:agam/logic/trail/device_trail_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'synthetic_trail.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Trail chains official order, isolates accounts, restores and logs completion once', () async {
    final accountChanges = StreamController<Object?>.broadcast();
    String? uid = 'synthetic-A';
    final location = SyntheticLocation()..move(const GeoPoint(-6.89, 107.6075));
    final session = SyntheticSession();
    final map = FakeMapConfig(pois: syntheticPois);
    final navigation = DeviceNavigationController(
      location: location,
      session: session,
      map: map,
      routing: CampusRoutingService.fromGeoJson(syntheticGraph),
    );
    var completionCount = 0;
    final repo = FakePoiRepository(
      pois: syntheticPois.reversed.toList(),
      facilities: [],
    );
    DeviceTrailService create() => DeviceTrailService(
      pois: repo,
      location: location,
      visits: AccountVisitStore(),
      currentUid: () => uid,
      accounts: accountChanges.stream,
      session: session,
      navigation: navigation,
      map: map,
      routingAvailable: true,
      onComplete: () => completionCount++,
    );
    var trail = create();
    addTearDown(() async {
      await trail.dispose();
      await navigation.stop();
      await session.dispose();
      await accountChanges.close();
      await location.controller.close();
    });

    await pumpEventQueue();
    expect(trail.current.nextPoiId, syntheticPois[0].id);
    session.trigger(1, mode: SessionMode.explore);
    await trail.start();
    await session.start(SessionMode.trail);
    await pumpEventQueue();
    expect(navigation.current.target?.id, syntheticPois[0].id);
    expect(navigation.current.status, NavigationStatus.onRoute);

    session.trigger(2);
    session.trigger(2);
    session.trigger(0);
    await pumpEventQueue();
    expect(trail.current.visitedCount, 2);
    expect(trail.current.nextPoiId, syntheticPois[1].id);
    expect(navigation.current.target?.id, syntheticPois[1].id);

    await session.end();
    await pumpEventQueue();
    expect(trail.current.active, false);
    expect(navigation.current.status, NavigationStatus.idle);
    await trail.dispose();
    trail = create();
    await pumpEventQueue();
    expect(trail.current.visitedCount, 2);
    expect(trail.current.nextPoiId, syntheticPois[1].id);

    uid = 'synthetic-B';
    accountChanges.add(null);
    expect(trail.current.visitedCount, 0);
    await pumpEventQueue();
    expect(trail.current.visitedCount, 0);
    uid = 'synthetic-A';
    accountChanges.add(null);
    await pumpEventQueue();
    expect(trail.current.visitedCount, 2);

    await trail.start();
    await session.start(SessionMode.trail);
    for (final index in [1, 3, 4, 5, 6, 7, 8, 9, 9]) {
      session.trigger(index);
    }
    await pumpEventQueue(times: 100);
    expect(trail.current.visitedCount, 10);
    expect(trail.current.completedAt, DateTime(2026, 1, 2));
    expect(navigation.current.status, NavigationStatus.idle);
    expect(session.current.isActive, false);
    expect(completionCount, 1);

    await trail.dispose();
    trail = create();
    await pumpEventQueue();
    expect(trail.current.isComplete, true);
    expect(completionCount, 1);
    await trail.reset();
    expect(trail.current.visitedCount, 0);
    expect(trail.current.completedAt, isNull);
  });

  test('recommendations rank by distance or Trail order and discard a switched UID', () async {
    final repo = FakePoiRepository(pois: syntheticPois, facilities: []);
    final visits = AccountVisitStore();
    final session = SyntheticSession();
    final fakeTrail = FakeTrailService(
      session: session,
      order: syntheticPois.reversed.map((p) => p.id).toList(),
    );
    addTearDown(() async {
      await fakeTrail.dispose();
      await session.dispose();
    });
    const first = 'synthetic-A';
    var uid = first;
    await visits.record(first, syntheticPois[1].id);
    final services = RepositoryRecommendationService(
      pois: repo,
      facilities: RepositoryFacilityService(repo),
      visited: visits.read,
      currentUid: () => uid,
      trail: fakeTrail,
    );
    final from = syntheticPois.first.position;
    Future<Recommendation> recommend() =>
        services.recommend(from: from, afterPoiId: syntheticPois.first.id);
    expect(
      (await recommend()).poiIds,
      syntheticPois.skip(2).take(3).map((p) => p.id),
    );
    uid = 'synthetic-B';
    expect(
      (await recommend()).poiIds,
      syntheticPois.skip(1).take(3).map((p) => p.id),
    );
    await fakeTrail.start();
    expect(
      (await recommend()).poiIds,
      syntheticPois.reversed.take(3).map((p) => p.id),
    );
    await fakeTrail.stop();
    final request = recommend();
    uid = first;
    final result = await request;
    expect(result.poiIds, isEmpty);
    expect(result.nearbyFacilities, isEmpty);
    for (final poi in syntheticPois) {
      await visits.record(first, poi.id);
    }
    expect((await recommend()).poiIds, isEmpty);
  });
}
