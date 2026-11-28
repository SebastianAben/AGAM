import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/search/poi_search_service.dart';
import 'package:agam/logic/session/poi_trial_control.dart';
import 'package:agam/logic/trail/account_visit_store.dart';
import 'package:agam/ui/app.dart';
import 'package:agam/ui/explore_map_screen.dart';
import 'package:agam/ui/orientation_trail_screen.dart';
import 'package:agam/ui/poi_detail_screen.dart';
import 'package:agam/ui/widgets/offline_campus_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic service fixtures; these tests do not simulate a real GPS journey.
AppServices demoServices({LocationService? location}) {
  final fake = AppServices.fake(tick: const Duration(hours: 1));
  return AppServices(
    permissions: fake.permissions,
    location: location ?? fake.location,
    pois: fake.pois,
    session: _RecordingSession(),
    audio: fake.audio,
    voice: fake.voice,
    settings: fake.settings,
    auth: fake.auth,
    activity: fake.activity,
    map: fake.map,
    routing: fake.routing,
    navigation: _UnavailableNavigation(),
    search: PoiSearchService(pois: fake.pois),
    recommendations: fake.recommendations,
    trail: const UnavailableTrailService(),
    facilities: fake.facilities,
  );
}

// Starting or stopping unfinished navigation must fail this test; screens
// may only observe its idle state. The demo trail screen reads the trail
// service, which has no order here.
class _UnavailableNavigation implements NavigationController {
  @override
  NavigationState get current => const NavigationState.idle();
  @override
  Stream<NavigationState> get state => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Demo accessed navigation: ${invocation.memberName}');
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
  final events = StreamController<PoiTriggerEvent>.broadcast();
  @override
  Stream<PoiTriggerEvent> get triggers => events.stream;
  void fire(String id, {TriggerResponse response = TriggerResponse.full}) {
    events.add(
      PoiTriggerEvent(
        poiId: id,
        mode: current.mode,
        response: response,
        triggeredAt: DateTime.utc(2026),
      ),
    );
  }

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

// SINTETIS: posisi fixture tetap di memori, tanpa GPS/jaringan.
class _StaticLocation implements LocationService {
  _StaticLocation(this.lastFix);
  @override
  final LocationFix lastFix;
  @override
  Stream<LocationFix> get positions => const Stream.empty();
}

// SINTETIS: posisi dipancarkan manual oleh test, tanpa GPS/jaringan.
class _StreamLocation implements LocationService {
  final controller = StreamController<LocationFix>.broadcast();
  @override
  LocationFix? lastFix;
  @override
  Stream<LocationFix> get positions => controller.stream;
  void emit(LocationFix fix) {
    lastFix = fix;
    controller.add(fix);
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // An earlier test may leave the binding detached; start on screen.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

GeoPoint? _userPosition(WidgetTester tester) =>
    tester.widget<OfflineCampusMap>(find.byType(OfflineCampusMap)).userPosition;

String _detailId(WidgetTester tester) =>
    tester.widget<PoiDetailScreen>(find.byType(PoiDetailScreen)).poi.id;

void main() {
  tearDown(rootBundle.clear);

  testWidgets(
    'foreground selects nearest triggered POI across tabs; background waits for resume',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fake = AppServices.fake(tick: const Duration(hours: 1));
      final nearest = (await fake.pois.poiById('P01'))!;
      final services = demoServices(
        location: _StaticLocation(
          LocationFix(
            position: nearest.position,
            accuracyM: 5,
            timestamp: DateTime.utc(2026),
          ),
        ),
      );
      final session = services.session as _RecordingSession;
      await session.start(SessionMode.explore);
      await tester.pumpWidget(
        MaterialApp(home: AgamMainShell(services: services)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trail')); // Any tab other than Jelajah.
      await tester.pumpAndSettle();
      session.fire('P01');
      session.fire('P02'); // Farther event arrives last: it must not win.
      await tester.pumpAndSettle();
      expect(find.text('Lihat'), findsOneWidget);
      expect(
        tester
            .widget<OfflineCampusMap>(find.byType(OfflineCampusMap))
            .selectedPoiId,
        'P01',
      );
      await tester.ensureVisible(find.text('Lewati'));
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trail')); // Any tab other than Jelajah.
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      session.fire('P02');
      await tester.pumpAndSettle();
      expect(find.byType(OfflineCampusMap), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Lihat'), findsOneWidget);
      expect(
        tester
            .widget<OfflineCampusMap>(find.byType(OfflineCampusMap))
            .selectedPoiId,
        'P02',
      );
      await session.end();
      await tester.pumpAndSettle();
      expect(find.text('Lihat'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await session.events.close();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    },
  );

  testWidgets('a POI skipped from the notification does not return on resume', (
    tester,
  ) async {
    _phone(tester);
    final fake = AppServices.fake(tick: const Duration(hours: 1));
    final p01 = (await fake.pois.poiById('P01'))!;
    final services = demoServices(
      location: _StaticLocation(
        LocationFix(
          position: p01.position,
          accuracyM: 5,
          timestamp: DateTime.utc(2026),
        ),
      ),
    );
    final session = services.session as _RecordingSession;
    final dismissed = StreamController<String>.broadcast();
    addTearDown(dismissed.close);
    await session.start(SessionMode.explore);
    await tester.pumpWidget(
      MaterialApp(
        home: AgamMainShell(services: services, poiDismissed: dismissed.stream),
      ),
    );
    await tester.pumpAndSettle();
    session.fire('P01');
    await tester.pumpAndSettle();
    expect(find.text('Lewati'), findsOneWidget);

    // "Lewati" on the notification while the app is in the background.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    dismissed.add('P01');
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Lewati'), findsNothing);
    expect(find.text('Lihat'), findsNothing);

    // Another POI still triggers normally afterwards.
    session.fire('P02');
    await tester.pumpAndSettle();
    expect(find.text('Lewati'), findsOneWidget);
    await session.end();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('session card names the running mode', (tester) async {
    _phone(tester);
    final services = demoServices();
    final session = services.session as _RecordingSession;
    await tester.pumpWidget(
      MaterialApp(home: AgamMainShell(services: services)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Explore'), findsOneWidget);
    expect(find.byTooltip('Mulai Explore'), findsOneWidget);

    await session.start(SessionMode.explore);
    await tester.pumpAndSettle();
    expect(find.text('Explore aktif'), findsOneWidget);
    expect(find.byTooltip('Akhiri sesi'), findsOneWidget);

    await session.start(SessionMode.navigation);
    await tester.pumpAndSettle();
    expect(find.text('Navigasi aktif'), findsOneWidget);
    expect(find.text('Explore aktif'), findsNothing);
    expect(find.byTooltip('Akhiri sesi'), findsOneWidget);

    // Trail is never shown as Explore; its action opens the Trail tab,
    // where progress and ending the trail live.
    await session.start(SessionMode.trail);
    await tester.pumpAndSettle();
    expect(find.text('Trail aktif'), findsOneWidget);
    expect(find.text('Explore aktif'), findsNothing);
    expect(find.byTooltip('Akhiri sesi'), findsNothing);
    await tester.tap(find.byTooltip('Buka Orientation Trail'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OrientationTrailScreen>(find.byType(OrientationTrailScreen))
          .isActive,
      isTrue,
    );
    expect(session.current.mode, SessionMode.trail);
    await session.end();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('inactive keeps the location dot; hidden clears it', (
    tester,
  ) async {
    _phone(tester);
    final fake = AppServices.fake(tick: const Duration(hours: 1));
    final p01 = (await fake.pois.poiById('P01'))!;
    final location = _StreamLocation();
    addTearDown(location.controller.close);
    final services = demoServices(location: location);
    await tester.pumpWidget(
      MaterialApp(home: AgamMainShell(services: services)),
    );
    await tester.pumpAndSettle();
    final fix = LocationFix(
      position: p01.position,
      accuracyM: 5,
      timestamp: DateTime.utc(2026),
    );
    location.emit(fix);
    await tester.pumpAndSettle();
    expect(_userPosition(tester), p01.position);

    // Pulling down the notification shade only makes the app inactive.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(_userPosition(tester), p01.position);
    location.emit(fix);
    await tester.pumpAndSettle();
    expect(_userPosition(tester), p01.position);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(location.controller.hasListener, isFalse);
    // Frames are paused while hidden; resuming renders the cleared dot before
    // any fresh fix arrives and re-subscribes to location updates.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_userPosition(tester), isNull);
    expect(location.controller.hasListener, isTrue);
    location.emit(fix);
    await tester.pumpAndSettle();
    expect(_userPosition(tester), p01.position);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'notification "Lihat" replaces an open detail and closes profile',
    (tester) async {
      _phone(tester);
      final services = demoServices();
      final views = StreamController<String>.broadcast();
      addTearDown(views.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AgamMainShell(
            services: services,
            poiViewRequests: views.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();

      views.add('P01');
      await tester.pumpAndSettle();
      expect(_detailId(tester), 'P01');
      // "Lihat" for another POI while P01 is open: not dropped, not stacked.
      views.add('P02');
      await tester.pumpAndSettle();
      expect(find.byType(PoiDetailScreen), findsOneWidget);
      expect(_detailId(tester), 'P02');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(PoiDetailScreen), findsNothing);
      expect(find.byType(ExploreMapScreen), findsOneWidget);

      // From the Trail tab with the profile open, the detail lands on
      // Jelajah with nothing left under it.
      await tester.tap(find.text('Trail'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profil & pengaturan'));
      await tester.pumpAndSettle();
      expect(find.text('Profil Pengguna'), findsOneWidget);
      views.add('P01');
      await tester.pumpAndSettle();
      expect(_detailId(tester), 'P01');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Profil Pengguna'), findsNothing);
      expect(find.byType(PoiDetailScreen), findsNothing);
      expect(
        tester.widget<ExploreMapScreen>(find.byType(ExploreMapScreen)).isActive,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('map alone: a second view request replaces the open detail', (
    tester,
  ) async {
    _phone(tester);
    final services = demoServices();
    final views = StreamController<String>.broadcast();
    addTearDown(views.close);
    await tester.pumpWidget(
      MaterialApp(
        home: ExploreMapScreen(
          services: services,
          poiViewRequests: views.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    views.add('P01');
    await tester.pumpAndSettle();
    views.add('P01'); // Same POI again: still one detail.
    await tester.pumpAndSettle();
    expect(find.byType(PoiDetailScreen), findsOneWidget);
    views.add('P02');
    await tester.pumpAndSettle();
    expect(find.byType(PoiDetailScreen), findsOneWidget);
    expect(_detailId(tester), 'P02');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(PoiDetailScreen), findsNothing);
    // A new request after closing still opens.
    views.add('P01');
    await tester.pumpAndSettle();
    expect(_detailId(tester), 'P01');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
