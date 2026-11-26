import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/contracts/fakes/fake_lb_services.dart';
import 'package:agam/logic/data/poi_codec.dart';
import 'package:agam/logic/map/agam_map_config.dart';
import 'package:agam/logic/routing/campus_routing_service.dart';
import 'package:agam/logic/routing/device_navigation_controller.dart';
import 'package:agam/logic/trail/device_trail_service.dart';
import 'package:agam/logic/trail/trail_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'synthetic_trail.dart';

/// Posisi sintetis tepat di sebelah utara POI sintetis [index] (±5 m).
GeoPoint near(int index) =>
    GeoPoint(-6.88995, unverifiedSyntheticPois[index].position.lng);

/// Urutan keliling sintetis yang dimulai dari [start], dihitung terpisah
/// dari implementasi.
List<String> loopFrom(int start) => [
  for (var i = 0; i < 10; i++) 'synthetic-${(start + i) % 10}',
];

class _Harness {
  _Harness({this.fixTimeout = const Duration(seconds: 3)}) {
    navigation = DeviceNavigationController(
      location: location,
      session: session,
      map: map,
      routing: CampusRoutingService.fromGeoJson(syntheticGraph),
    );
  }

  final Duration fixTimeout;
  final accounts = StreamController<Object?>.broadcast();
  final location = SyntheticLocation();
  final session = SyntheticSession();
  final map = FakeMapConfig(pois: unverifiedSyntheticPois);
  final activity = FakeActivityLogger();
  final repo = FakePoiRepository(pois: unverifiedSyntheticPois, facilities: []);
  late final DeviceNavigationController navigation;
  String? uid = 'synthetic-A';
  final _created = <DeviceTrailService>[];

  DeviceTrailService create() {
    final trail = createDeviceTrailService(
      pois: repo,
      location: location,
      session: session,
      navigation: navigation,
      map: map,
      activity: activity,
      currentUid: () => uid,
      accounts: accounts.stream,
      routingAvailable: true,
      startFixTimeout: fixTimeout,
    );
    _created.add(trail);
    return trail;
  }

  Future<void> switchTo(String? next) async {
    uid = next;
    accounts.add(null);
    await pumpEventQueue();
  }

  Future<void> startTrail(DeviceTrailService trail) async {
    await trail.start();
    await session.start(SessionMode.trail);
    await pumpEventQueue();
  }

  Future<void> dispose() async {
    for (final trail in _created) {
      await trail.dispose();
    }
    await navigation.stop();
    await session.dispose();
    await accounts.close();
    await location.controller.close();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('first start begins at the nearest POI with unverified access points, '
      'persists per account, and reset picks again', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    var trail = h.create();
    await pumpEventQueue();
    // Before the first start the official loop is shown as is.
    expect(trail.current.order, loopFrom(0));

    h.location.move(near(7));
    await h.startTrail(trail);
    expect(trail.current.active, isTrue);
    expect(trail.current.order, loopFrom(7));
    expect(trail.current.order.sublist(2, 4), ['synthetic-9', 'synthetic-0']);
    expect(trail.current.nextPoiId, 'synthetic-7');
    expect(h.navigation.current.target?.id, 'synthetic-7');
    // The user stands next to the start, so the route ends right away.
    expect(h.navigation.current.status, NavigationStatus.arrived);

    h.session.trigger(7);
    await pumpEventQueue(times: 50);
    expect(h.navigation.current.target?.id, 'synthetic-8');
    await h.session.end();
    await pumpEventQueue();

    // Restored after restart, even when the user is now elsewhere.
    h.location.move(near(2));
    trail = h.create();
    await pumpEventQueue();
    expect(trail.current.order, loopFrom(7));
    expect(trail.current.nextPoiId, 'synthetic-8');
    await trail.start();
    expect(trail.current.order, loopFrom(7));
    await trail.stop();

    // Another account gets its own start.
    await h.switchTo('synthetic-B');
    expect(trail.current.order, loopFrom(0));
    await trail.start();
    expect(trail.current.order, loopFrom(2));
    await trail.stop();
    await h.switchTo('synthetic-A');
    expect(trail.current.order, loopFrom(7));
    expect(trail.current.visitedCount, 1);

    // Reset clears progress and the start; the next start picks again.
    await trail.reset();
    expect(trail.current.order, loopFrom(0));
    expect(trail.current.visitedCount, 0);
    h.location.move(near(4));
    await trail.start();
    expect(trail.current.order, loopFrom(4));
    expect(
      await SharedPreferences.getInstance().then(
        (p) => p.getKeys().where((k) => k.contains('trailStart')).toSet(),
      ),
      {'account.synthetic-A.trailStart', 'account.synthetic-B.trailStart'},
    );
  });

  test('without a last fix the next fix picks the start', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    final trail = h.create();
    await pumpEventQueue();
    final started = trail.start();
    await pumpEventQueue();
    h.location.move(near(5));
    await started;
    expect(trail.current.order, loopFrom(5));
  });

  test('without any fix the trail starts at trailOrder 1', () async {
    final h = _Harness(fixTimeout: Duration.zero);
    addTearDown(h.dispose);
    final trail = h.create();
    await pumpEventQueue();
    await trail.start();
    expect(trail.current.order, loopFrom(0));
    expect(trail.current.active, isTrue);
  });

  test('out-of-order check-ins count and completion logs trailCompleted '
      'once with date precision', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    final trail = h.create();
    await pumpEventQueue();
    h.location.move(near(7));
    await h.startTrail(trail);
    for (final index in [0, 1, 2, 3, 4, 5, 6, 9, 8, 7, 7]) {
      h.session.trigger(index);
    }
    await pumpEventQueue(times: 200);
    expect(trail.current.visitedCount, 10);
    expect(trail.current.isComplete, isTrue);
    expect(trail.current.completedAt, DateTime(2026, 1, 2));
    expect(h.session.current.isActive, isFalse);

    expect(h.activity.events, hasLength(1));
    final event = h.activity.events.single;
    expect(event, isA<TrailCompletedEvent>());
    expect(event.type, 'trailCompleted');
    expect(event.timePrecision, ActivityTimePrecision.dateOnly);
    expect(event.fields, isEmpty);

    // Restarting the service does not log the completion again.
    h.create();
    await pumpEventQueue();
    expect(h.activity.events, hasLength(1));
  });

  test('the bundled dataset can start the trail inside the campus', () async {
    final text = File('assets/data/pois.json').readAsStringSync();
    final pois = decodePoiDataset(jsonDecode(text)).pois;
    final official = pois.where((poi) => poi.trailOrder != null).toList()
      ..sort((a, b) => a.trailOrder!.compareTo(b.trailOrder!));
    expect(official, hasLength(10));
    expect(official.any((poi) => poi.hasSurveyedEntrance), isFalse);

    final location = SyntheticLocation();
    final session = SyntheticSession();
    final map = AgamMapConfig.campus();
    final navigation = FakeNavigationController(
      location: location,
      routing: FakeRoutingService(),
    );
    final trail = createDeviceTrailService(
      pois: FakePoiRepository(pois: pois, facilities: []),
      location: location,
      session: session,
      navigation: navigation,
      map: map,
      activity: FakeActivityLogger(),
      currentUid: () => 'synthetic-A',
      accounts: const Stream.empty(),
      routingAvailable: true,
    );
    addTearDown(() async {
      await trail.dispose();
      await session.dispose();
      await location.controller.close();
    });
    await pumpEventQueue();

    // Standing at the fourth stop's first access point.
    final fourth = official[3];
    location.move(fourth.entrances.first.position);
    await trail.start();
    expect(trail.current.active, isTrue);
    expect(trail.current.order, [
      for (var i = 0; i < 10; i++) official[(3 + i) % 10].id,
    ]);
  });
}
