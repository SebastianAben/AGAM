import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/search/poi_search_service.dart';
import 'package:agam/logic/session/poi_trial_control.dart';
import 'package:agam/ui/orientation_trail_screen.dart';
import 'package:agam/ui/poi_detail_screen.dart';
import 'package:agam/ui/profile_preview_screen.dart';
import 'package:agam/ui/search_route_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic service fixtures; these tests do not simulate a real GPS journey.
AppServices demoServices() {
  final fake = AppServices.fake(tick: const Duration(hours: 1));
  return AppServices(
    permissions: fake.permissions,
    location: fake.location,
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
    trail: _UnavailableTrail(),
    facilities: fake.facilities,
  );
}

// Any access to unfinished runtime services must fail this test.
class _UnavailableNavigation implements NavigationController {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Demo accessed navigation: ${invocation.memberName}');
}

class _UnavailableTrail implements TrailService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Demo accessed trail: ${invocation.memberName}');
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
    expect(detail.navigationAvailable, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await services.session.end();
  });

  testWidgets('filter menu changes results and clear resets query', (
    tester,
  ) async {
    final services = demoServices();
    await tester.pumpWidget(
      MaterialApp(
        home: SearchRouteScreen(services: services, internalDemo: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'labtek 5');
    await tester.pumpAndSettle();
    expect(find.text('Labtek V'), findsOneWidget);
    await tester.tap(find.byTooltip('Filter kategori'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Ruang Kuliah'));
    await tester.pumpAndSettle();
    expect(find.text('Labtek V'), findsNothing);
    expect(find.text('Tidak ada hasil yang cocok.'), findsOneWidget);
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
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(services.settings.current.autoPlayNarration, isTrue);
    await tester.ensureVisible(find.text('Akhiri'));
    await tester.tap(find.text('Akhiri'));
    await tester.pumpAndSettle();
    expect(services.session.current.isActive, isFalse);
    expect(find.text('Tidak ada sesi aktif'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
