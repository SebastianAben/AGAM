import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/search/poi_search_service.dart';
import 'package:agam/logic/session/poi_trial_control.dart';
import 'package:agam/logic/trail/account_visit_store.dart';
import 'package:agam/ui/app.dart';
import 'package:agam/ui/widgets/offline_campus_map.dart';
import 'package:flutter/material.dart';
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

void main() {
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
}
