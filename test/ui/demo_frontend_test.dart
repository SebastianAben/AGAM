import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/contracts/fakes/fake_lb_services.dart';
import 'package:agam/logic/search/poi_search_service.dart';
import 'package:agam/logic/trail/account_visit_store.dart';
import 'package:agam/logic/session/poi_trial_control.dart';
import 'package:agam/ui/orientation_trail_screen.dart';
import 'package:agam/ui/poi_detail_screen.dart';
import 'package:agam/ui/profile_preview_screen.dart';
import 'package:agam/ui/search_route_screen.dart';
import 'package:agam/ui/walking_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../logic/trail/synthetic_trail.dart';

// Synthetic service fixtures; these tests do not simulate a real GPS journey.
AppServices demoServices({
  PoiRepository? pois,
  TrailService Function(SessionController session)? trail,
  NavigationController? navigation,
  LocationService? location,
}) {
  final fake = AppServices.fake(tick: const Duration(hours: 1));
  final session = _RecordingSession();
  return AppServices(
    permissions: fake.permissions,
    location: location ?? fake.location,
    pois: pois ?? fake.pois,
    session: session,
    audio: fake.audio,
    voice: fake.voice,
    settings: fake.settings,
    auth: fake.auth,
    activity: fake.activity,
    map: fake.map,
    routing: fake.routing,
    // The demo routes on the bundled campus graph, like the product build.
    navigation: navigation ?? fake.navigation,
    search: PoiSearchService(pois: fake.pois),
    recommendations: fake.recommendations,
    trail: trail?.call(session) ?? const UnavailableTrailService(),
    facilities: fake.facilities,
  );
}

/// Synthetic trail whose start() rotates the loop, like the first start of
/// the device trail service near another stop.
class _RotatingTrail implements TrailService {
  _RotatingTrail(this._before, this._after);

  final List<String> _before;
  final List<String> _after;
  final _changes = StreamController<TrailProgress>.broadcast();
  late TrailProgress _current = TrailProgress(
    order: _before,
    visited: const {},
    active: false,
  );

  @override
  TrailProgress get current => _current;
  @override
  Stream<TrailProgress> get progress => _changes.stream;
  @override
  Future<void> start() async {
    _current = TrailProgress(order: _after, visited: const {}, active: true);
    _changes.add(_current);
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> reset() async {}
}

class _RecordingNavigation implements NavigationController {
  final _states = StreamController<NavigationState>.broadcast();
  @override
  NavigationState current = const NavigationState.idle();
  @override
  Stream<NavigationState> get state => _states.stream;
  @override
  Future<void> start(NavigationTarget target) async {
    current = NavigationState(
      status: NavigationStatus.calculating,
      target: target,
    );
    _states.add(current);
  }

  @override
  Future<void> stop() async {
    current = const NavigationState.idle();
    _states.add(current);
  }
}

class _HeldLocation implements LocationService {
  _HeldLocation(GeoPoint position)
    : lastFix = LocationFix(
        position: position,
        accuracyM: 5,
        timestamp: DateTime(2026),
      );

  @override
  final LocationFix? lastFix;

  @override
  Stream<LocationFix> get positions => const Stream.empty();
}

class _RecordingSession implements SessionController, PoiTrialControl {
  @override
  bool get trialModeAvailable => true;
  @override
  bool trialModeEnabled = false;
  final _trialChanges = StreamController<bool>.broadcast();
  @override
  Stream<bool> get trialModeChanges => _trialChanges.stream;
  @override
  void setTrialMode(bool enabled) {
    trialModeEnabled = enabled;
    _trialChanges.add(enabled);
  }

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

void main() {
  testWidgets('developer trial is hidden outside the internal demo', (
    tester,
  ) async {
    final services = demoServices();
    await tester.pumpWidget(
      MaterialApp(home: ProfilePreviewScreen(services: services)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mode demo/trial'), findsNothing);
    expect((services.session as PoiTrialControl).trialModeEnabled, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('trail preview cannot start or replace an Explore session', (
    tester,
  ) async {
    final services = demoServices();
    await services.session.start(SessionMode.explore);
    await tester.pumpWidget(
      MaterialApp(
        home: OrientationTrailScreen(services: services, internalDemo: true),
      ),
    );
    await tester.pumpAndSettle();
    final start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Mulai Trail'),
    );
    expect(start.onPressed, isNull);
    expect(find.textContaining('sintetis'), findsNothing);
    expect(find.textContaining('PRATINJAU'), findsNothing);
    expect(services.session.current.mode, SessionMode.explore);
    await tester.pumpWidget(const SizedBox.shrink());
    await services.session.end();
  });

  testWidgets('demo trail follows the trail service order and starts there', (
    tester,
  ) async {
    // Synthetic rotated order, as if the nearest POI were the fifth stop.
    final order = [
      for (var i = 0; i < 10; i++) unverifiedSyntheticPois[(4 + i) % 10].id,
    ];
    final services = demoServices(
      pois: FakePoiRepository(pois: unverifiedSyntheticPois, facilities: []),
      trail: (session) => FakeTrailService(session: session, order: order),
      navigation: _RecordingNavigation(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OrientationTrailScreen(services: services, internalDemo: true),
      ),
    );
    await tester.pumpAndSettle();
    final names = {for (final poi in unverifiedSyntheticPois) poi.id: poi.name};
    expect(find.text('Urutan trail belum tersedia.'), findsNothing);
    // The first card in the list is the start picked by the service.
    final firstCard = tester.getTopLeft(find.text(names[order[0]]!).first).dy;
    final secondCard = tester.getTopLeft(find.text(names[order[1]]!).first).dy;
    expect(firstCard, lessThan(secondCard));

    await tester.tap(find.widgetWithText(FilledButton, 'Mulai Trail'));
    // A route in progress keeps an indicator moving; pump a bounded time.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(services.trail.current.active, isTrue);
    expect(services.session.current.mode, SessionMode.trail);
    expect(services.navigation.current.target?.id, order[0]);
    expect(find.text('Tujuan perkiraan'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await services.navigation.stop();
    await services.session.end();
  });

  testWidgets('next stop route goes to the start picked by the service', (
    tester,
  ) async {
    final before = [for (final poi in unverifiedSyntheticPois) poi.id];
    final after = [...before.skip(6), ...before.take(6)];
    final services = demoServices(
      pois: FakePoiRepository(pois: unverifiedSyntheticPois, facilities: []),
      trail: (_) => _RotatingTrail(before, after),
      navigation: _RecordingNavigation(),
      // SYNTHETIC: a fix already in memory, so the preview can plan.
      location: _HeldLocation(unverifiedSyntheticPois.first.position),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OrientationTrailScreen(services: services, internalDemo: true),
      ),
    );
    await tester.pumpAndSettle();
    // Before the first start the card of trailOrder 1 is the next stop. Its
    // Rute opens the preview; "Mulai rute" starts the trail.
    await tester.tap(find.widgetWithText(FilledButton, 'Rute'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(services.session.current.mode, SessionMode.none);
    await tester.tap(find.text(WalkingNavigationScreen.startLabel));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(services.session.current.mode, SessionMode.trail);
    expect(services.navigation.current.target?.id, after.first);
    expect(find.text('Tujuan perkiraan'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    // This navigation never leaves "calculating"; let the start give up.
    await tester.pump(const Duration(seconds: 13));
    await tester.pumpWidget(const SizedBox.shrink());
    // The route map asked rootBundle for the placeholder style inside this
    // test's fake zone; a cached future from that zone would never resolve
    // for the next test's map.
    rootBundle.clear();
    await services.navigation.stop();
    await services.session.end();
  });

  testWidgets('alias search opens a map and detail without changing Explore', (
    tester,
  ) async {
    final services = demoServices();
    await services.session.start(SessionMode.explore);
    await tester.pumpWidget(
      MaterialApp(
        home: SearchRouteScreen(services: services, internalDemo: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'labtek 5');
    await tester.pumpAndSettle();
    expect(find.text('Labtek V'), findsOneWidget);
    await tester.tap(find.text('Labtek V'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tampilkan di peta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tampilkan di peta'));
    await tester.pumpAndSettle();
    expect(find.text('Navigasi (pratinjau)'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(services.session.current.mode, SessionMode.explore);
    await tester.ensureVisible(find.text('Tutup pilihan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutup pilihan'));
    await tester.pumpAndSettle();
    expect(services.session.current.mode, SessionMode.explore);
    await tester.ensureVisible(find.text('Labtek V'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Labtek V'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lihat Detail POI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat Detail POI'));
    await tester.pumpAndSettle();
    final detail = tester.widget<PoiDetailScreen>(find.byType(PoiDetailScreen));
    expect(detail.poi.id, 'P01');
    // The demo routes too: Rute on the detail starts navigation.
    expect(detail.navigationAvailable, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await services.session.end();
  });

  testWidgets('facility tiles filter results and clear resets query', (
    tester,
  ) async {
    final services = demoServices();
    await tester.pumpWidget(
      MaterialApp(
        home: SearchRouteScreen(services: services, internalDemo: true),
      ),
    );
    await tester.pumpAndSettle();
    // PRD F05 "filter kategori" means facility categories; building-type
    // filters split Labtek from lecture buildings, which PRD §9.1 contradicts.
    expect(find.byTooltip('Filter kategori'), findsNothing);
    expect(find.text('Ruang Kuliah'), findsNothing);
    expect(find.text('Laboratorium'), findsNothing);
    expect(find.text('Labtek V'), findsOneWidget);
    // The tiles sit below the building list, outside the first build.
    await tester.scrollUntilVisible(
      find.text('Musala'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Musala'));
    await tester.pumpAndSettle();
    expect(find.text('Labtek V'), findsNothing); // Buildings step aside.
    expect(find.text('Data musala belum tersedia.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'labtek 5');
    await tester.pumpAndSettle();
    expect(find.text('Labtek V'), findsNothing);
    expect(find.text('Data musala belum tersedia.'), findsOneWidget);
    // The active filter stays visible while typing and clears with one tap.
    await tester.tap(find.text('Musala'));
    await tester.pumpAndSettle();
    expect(find.text('Labtek V'), findsOneWidget);
    await tester.tap(find.byTooltip('Hapus pencarian'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text('Hasil Pencarian'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings updates autoplay and ends the active session', (
    tester,
  ) async {
    final services = demoServices();
    await services.session.start(SessionMode.explore);
    await tester.pumpWidget(
      MaterialApp(home: ProfilePreviewScreen(services: services)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(services.settings.current.autoPlayNarration, isTrue);
    await tester.ensureVisible(find.text('Akhiri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akhiri'));
    await tester.pumpAndSettle();
    expect(services.session.current.isActive, isFalse);
    expect(find.text('Tidak ada sesi aktif'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
