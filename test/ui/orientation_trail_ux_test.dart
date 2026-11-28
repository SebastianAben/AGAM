import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/contracts/fakes/fake_lb_services.dart';
import 'package:agam/ui/orientation_trail_screen.dart';
import 'package:agam/ui/walking_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../logic/trail/synthetic_trail.dart';

// UI08 Trail UX (B06, B17, B24). Every POI, position and distance here is a
// synthetic fixture; nothing simulates a real GPS journey.

final _order = [for (final poi in unverifiedSyntheticPois) poi.id];

AppServices _services({
  PermissionService? permissions,
  TrailService Function(SessionController session)? trail,
  NavigationController? navigation,
  List<Poi>? pois,
}) {
  final fake = AppServices.fake(tick: const Duration(hours: 1));
  final session = _RecordingSession();
  return AppServices(
    permissions: permissions ?? FakePermissionService(),
    // No fix: UI06 stays in its preview and plans nothing.
    location: _NoFixLocation(),
    pois: FakePoiRepository(
      pois: pois ?? unverifiedSyntheticPois,
      facilities: [],
    ),
    session: session,
    audio: fake.audio,
    voice: fake.voice,
    settings: fake.settings,
    auth: fake.auth,
    activity: fake.activity,
    map: fake.map,
    routing: fake.routing,
    navigation: navigation ?? _RecordingNavigation(),
    search: fake.search,
    recommendations: fake.recommendations,
    trail:
        trail?.call(session) ??
        FakeTrailService(session: session, order: _order),
    facilities: fake.facilities,
  );
}

class _NoFixLocation implements LocationService {
  @override
  LocationFix? get lastFix => null;
  @override
  Stream<LocationFix> get positions => const Stream.empty();
}

class _RecordingNavigation implements NavigationController {
  _RecordingNavigation({this.remainingDistanceM});

  final double? remainingDistanceM;
  final _states = StreamController<NavigationState>.broadcast();
  int starts = 0;

  @override
  NavigationState current = const NavigationState.idle();
  @override
  Stream<NavigationState> get state => _states.stream;
  @override
  Future<void> start(NavigationTarget target) async {
    starts++;
    current = NavigationState(
      status: NavigationStatus.onRoute,
      target: target,
      remainingDistanceM: remainingDistanceM,
    );
    _states.add(current);
  }

  @override
  Future<void> stop() async {
    current = const NavigationState.idle();
    _states.add(current);
  }
}

class _RecordingSession implements SessionController {
  final _states = StreamController<SessionState>.broadcast();
  @override
  SessionState current = const SessionState.idle();
  @override
  Stream<SessionState> get state => _states.stream;
  @override
  Stream<PoiTriggerEvent> get triggers => const Stream.empty();
  @override
  Future<void> start(SessionMode mode) async {
    current = SessionState(mode: mode, startedAt: DateTime(2026));
    _states.add(current);
  }

  @override
  Future<void> end() async {
    current = const SessionState.idle();
    _states.add(current);
  }
}

/// Synthetic trail whose progress stream can fail on demand.
class _FailingTrail implements TrailService {
  final changes = StreamController<TrailProgress>.broadcast();

  @override
  TrailProgress get current =>
      TrailProgress(order: _order, visited: const {}, active: false);
  @override
  Stream<TrailProgress> get progress => changes.stream;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> reset() async {}
}

Future<void> _pumpTrail(WidgetTester tester, AppServices services) async {
  await tester.pumpWidget(
    MaterialApp(home: OrientationTrailScreen(services: services)),
  );
  await tester.pumpAndSettle();
}

/// UI06 keeps an indicator moving; pump a bounded time instead of settling.
Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tearDown(WidgetTester tester, AppServices services) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // UI06's map asked rootBundle inside this test's fake zone; a cached
  // future from that zone would never resolve for the next test's map.
  rootBundle.clear();
  await services.navigation.stop();
  await services.session.end();
}

void main() {
  testWidgets('bottom Mulai Trail opens UI06 and starts nothing yet', (
    tester,
  ) async {
    addTearDown(rootBundle.clear);
    final services = _services();
    await _pumpTrail(tester, services);

    expect(find.text('Tujuan berikutnya'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Mulai Trail'));
    await _pumpRoute(tester);

    final route = tester.widget<WalkingNavigationScreen>(
      find.byType(WalkingNavigationScreen),
    );
    expect(route.trail, isTrue);
    expect(route.target.id, _order.first);
    // The preview waits for "Mulai rute"; no session or trail runs yet.
    expect(services.session.current.mode, SessionMode.none);
    expect(services.trail.current.active, isFalse);
    expect(services.navigation.current.status, NavigationStatus.idle);
    await _tearDown(tester, services);
  });

  for (final (status, text) in [
    (
      LocationPermissionStatus.serviceDisabled,
      'Aktifkan GPS perangkat untuk memulai Orientation Trail.',
    ),
    (
      LocationPermissionStatus.denied,
      'Izin lokasi akurat saat aplikasi digunakan diperlukan.',
    ),
    (
      LocationPermissionStatus.approximateOnly,
      'Izin lokasi akurat saat aplikasi digunakan diperlukan.',
    ),
  ]) {
    testWidgets('location ${status.name} keeps the trail closed', (
      tester,
    ) async {
      final services = _services(
        permissions: FakePermissionService(locationResult: status),
      );
      await _pumpTrail(tester, services);

      await tester.tap(find.widgetWithText(FilledButton, 'Mulai Trail'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(text), findsOneWidget);
      expect(find.byType(WalkingNavigationScreen), findsNothing);
      expect(services.session.current.mode, SessionMode.none);
      expect(services.trail.current.active, isFalse);
      await _tearDown(tester, services);
    });
  }

  testWidgets('Akhiri rute keeps the trail; Akhiri Trail ends it', (
    tester,
  ) async {
    addTearDown(rootBundle.clear);
    final navigation = _RecordingNavigation();
    final services = _services(navigation: navigation);
    await _pumpTrail(tester, services);

    await tester.tap(find.widgetWithText(FilledButton, 'Mulai Trail'));
    await _pumpRoute(tester);
    final route = tester.widget<WalkingNavigationScreen>(
      find.byType(WalkingNavigationScreen),
    );

    // What "Mulai rute" runs: trail, session and one route to the stop.
    await route.start!();
    expect(services.trail.current.active, isTrue);
    expect(services.session.current.mode, SessionMode.trail);
    expect(navigation.current.target?.id, _order.first);
    expect(navigation.starts, 1);

    // Starting again on the same running route does not restart it.
    await route.start!();
    expect(navigation.starts, 1);

    // What "Akhiri rute" runs: only this leg stops.
    await route.end!();
    expect(navigation.current.status, NavigationStatus.idle);
    expect(services.trail.current.active, isTrue);
    expect(services.session.current.mode, SessionMode.trail);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(WalkingNavigationScreen), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Buka peta rute'), findsOneWidget);

    await tester.tap(find.byTooltip('Akhiri Trail'));
    await tester.pumpAndSettle();
    expect(services.trail.current.active, isFalse);
    expect(services.session.current.mode, SessionMode.none);
    expect(find.byTooltip('Akhiri Trail'), findsNothing);
    await _tearDown(tester, services);
  });

  testWidgets('a trail.progress error shows a calm message, no crash', (
    tester,
  ) async {
    final trail = _FailingTrail();
    final services = _services(trail: (_) => trail);
    await _pumpTrail(tester, services);

    trail.changes.addError(StateError('synthetic failure'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('Progres trail belum dapat diperbarui.'), findsOneWidget);
    // The screen keeps working on the last known progress.
    expect(find.widgetWithText(FilledButton, 'Mulai Trail'), findsOneWidget);
    await _tearDown(tester, services);
    await trail.changes.close();
  });

  testWidgets('a long stop name and distance never overflow the bottom bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const longName =
        'Gedung Sintetis dengan Nama yang Sangat Panjang Sekali untuk Uji '
        'Tata Letak Tombol Bawah';
    final first = unverifiedSyntheticPois.first;
    final pois = [
      Poi(
        id: first.id,
        name: longName,
        aliases: first.aliases,
        category: first.category,
        position: first.position,
        radiusM: first.radiusM,
        entrances: first.entrances,
        description: first.description,
        function: first.function,
        facilities: first.facilities,
        trivia: first.trivia,
        media: first.media,
        metadata: first.metadata,
        trailOrder: first.trailOrder,
      ),
      ...unverifiedSyntheticPois.skip(1),
    ];
    final services = _services(
      pois: pois,
      navigation: _RecordingNavigation(remainingDistanceM: 1234),
    );
    await _pumpTrail(tester, services);

    // Start the trail toward the long-named stop without opening UI06.
    await services.trail.start();
    await services.session.start(SessionMode.trail);
    await services.navigation.start(NavigationTarget.poi(pois.first));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.widgetWithText(FilledButton, 'Lanjutkan navigasi'),
      findsOneWidget,
    );
    expect(find.text('1234 m'), findsOneWidget);
    // The name sits on its own line, outside the button label.
    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.textContaining('Sintetis dengan Nama'),
      ),
      findsNothing,
    );
    await _tearDown(tester, services);
  });
}
