import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_data.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/logic/search/poi_search_service.dart';
import 'package:agam/logic/session/trigger_notifier.dart';
import 'package:agam/ui/app.dart';
import 'package:agam/ui/poi_detail_screen.dart';
import 'package:agam/ui/search_route_screen.dart';
import 'package:agam/ui/widgets/facility_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS: fake services, fake POIs and a synthetic approved POI only.

const _poi = Poi(
  id: 'synthetic-log',
  name: 'SINTETIS',
  aliases: [],
  category: PoiCategory.lecture,
  position: GeoPoint(0, 0),
  radiusM: 15,
  entrances: [],
  description: 'SINTETIS deskripsi',
  function: 'SINTETIS fungsi',
  facilities: [],
  trivia: 'SINTETIS trivia',
  media: PoiMedia(narrationAudio: 'synthetic.mp3'),
  metadata: ContentMetadata(
    sources: ['SINTETIS'],
    verifiedAt: null,
    owner: 'SINTETIS',
    assetAttribution: [
      'assets/media/synthetic-log/foto.jpg — Foto: SINTETIS',
      'assets/media/synthetic-log/foto 2.jpg — Foto: SINTETIS',
      'Pengisi suara: SINTETIS',
    ],
    approved: true,
  ),
);

/// Every event recorded must be exactly one `featureUsed` with [feature].
/// The event type itself has no other field (PRD §15.5).
Matcher _onlyFeature(ActivityFeature feature) => equals([
  isA<FeatureUsedEvent>()
      .having((e) => e.type, 'type', 'featureUsed')
      .having((e) => e.feature, 'feature', feature),
]);

/// A session whose POI triggers the test fires by hand.
class _TriggerSession implements SessionController {
  final _states = StreamController<SessionState>.broadcast();
  final _triggers = StreamController<PoiTriggerEvent>.broadcast();
  @override
  SessionState current = const SessionState.idle();
  @override
  Stream<SessionState> get state => _states.stream;
  @override
  Stream<PoiTriggerEvent> get triggers => _triggers.stream;
  void fire(String id) => _triggers.add(
    PoiTriggerEvent(
      poiId: id,
      mode: current.mode,
      response: TriggerResponse.full,
      triggeredAt: DateTime.utc(2026),
    ),
  );
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

// SINTETIS: a fixed fix in memory, no GPS or network.
class _StaticLocation implements LocationService {
  _StaticLocation(this.lastFix);
  @override
  final LocationFix lastFix;
  @override
  Stream<LocationFix> get positions => const Stream.empty();
}

AppServices _services({SessionController? session, LocationService? location}) {
  final fake = AppServices.fake(tick: const Duration(hours: 1));
  return AppServices(
    permissions: fake.permissions,
    location: location ?? fake.location,
    pois: fake.pois,
    session: session ?? fake.session,
    audio: fake.audio,
    voice: fake.voice,
    settings: fake.settings,
    auth: fake.auth,
    activity: FakeActivityLogger(),
    map: fake.map,
    routing: fake.routing,
    navigation: fake.navigation,
    search: PoiSearchService(pois: fake.pois),
    recommendations: fake.recommendations,
    trail: fake.trail,
    facilities: fake.facilities,
  );
}

List<ActivityEvent> _events(AppServices services) =>
    (services.activity as FakeActivityLogger).events;

/// The live map keeps animating, so pumpAndSettle would never return.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('poiCard is logged once when the detail opens', (tester) async {
    _phone(tester);
    final services = _services();
    await tester.pumpWidget(
      MaterialApp(
        home: PoiDetailScreen(
          poi: _poi,
          activity: services.activity,
          audio: services.audio,
          onNavigate: () async {},
          checkedIn: false,
          navigationAvailable: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Rebuilds (expanding the transcript) do not log again.
    await tester.tap(find.text('Tentang gedung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tentang gedung'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Sumber'), 220);
    expect(
      find.text('SINTETIS\nFoto: SINTETIS\nPengisi suara: SINTETIS'),
      findsOneWidget,
    );
    expect(find.textContaining('assets/media/'), findsNothing);
    expect(_events(services), _onlyFeature(ActivityFeature.poiCard));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('narration is logged once per start, not on pause or resume', (
    tester,
  ) async {
    _phone(tester);
    final services = _services();
    await tester.pumpWidget(
      MaterialApp(
        home: PoiDetailScreen(
          poi: _poi,
          activity: services.activity,
          audio: services.audio,
          onNavigate: () async {},
          checkedIn: false,
          navigationAvailable: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    _events(services).clear();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();
    expect(services.audio.current.status, PlaybackStatus.playing);
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();
    expect(services.audio.current.status, PlaybackStatus.playing);

    expect(_events(services), _onlyFeature(ActivityFeature.narration));
    await services.audio.stop();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('search is logged once when a search first finds results', (
    tester,
  ) async {
    _phone(tester);
    final services = _services();
    await tester.pumpWidget(
      MaterialApp(home: SearchRouteScreen(services: services)),
    );
    await tester.pumpAndSettle();

    // A search without results is not a use yet.
    await tester.enterText(find.byType(TextField), 'zzzz tidak ada');
    await tester.pumpAndSettle();
    expect(_events(services), isEmpty);

    // Every keystroke runs a search; only the first hit logs.
    for (final text in ['l', 'la', 'lab', 'labtek', 'labtek 5']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.text('Labtek V'), findsWidgets);

    expect(_events(services), _onlyFeature(ActivityFeature.search));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('facilities is logged once when a category first filters', (
    tester,
  ) async {
    _phone(tester);
    final services = _services();
    await tester.pumpWidget(
      MaterialApp(home: SearchRouteScreen(services: services)),
    );
    await tester.pumpAndSettle();
    expect(_events(services), isEmpty);

    final tile = find.text(facilityName(FacilityCategory.toilet));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    // Off and on again in the same visit is the same use.
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    expect(_events(services), _onlyFeature(ActivityFeature.facilities));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('opening search on a facility chip logs facilities once', (
    tester,
  ) async {
    _phone(tester);
    final services = _services();
    await tester.pumpWidget(
      MaterialApp(
        home: SearchRouteScreen(
          services: services,
          initialFacility: FacilityCategory.toilet,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_events(services), _onlyFeature(ActivityFeature.facilities));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a detail opened from a POI trigger logs nothing', (
    tester,
  ) async {
    _phone(tester);
    final services = _services();
    final views = StreamController<String>.broadcast();
    addTearDown(views.close);
    await tester.pumpWidget(
      MaterialApp(
        home: AgamMainShell(services: services, poiViewRequests: views.stream),
      ),
    );
    await tester.pumpAndSettle();
    _events(services).clear();

    // "Lihat" on a trigger notification arrives as a view request.
    views.add('P01');
    await tester.pumpAndSettle();
    expect(find.byType(PoiDetailScreen), findsOneWidget);

    expect(_events(services), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('"Lihat" on the trigger card logs nothing', (tester) async {
    _phone(tester);
    final session = _TriggerSession();
    final services = _services(
      session: session,
      location: _StaticLocation(
        LocationFix(
          position: fakePois.first.position,
          accuracyM: 5,
          timestamp: DateTime.utc(2026),
        ),
      ),
    );
    final views = StreamController<String>.broadcast();
    addTearDown(views.close);
    await session.start(SessionMode.explore);
    await tester.pumpWidget(
      MaterialApp(
        home: AgamMainShell(
          services: services,
          poiViewRequests: views.stream,
          // As in the product: the action goes through the responder, which
          // answers "Lihat" with a view request.
          onPoiAction: (id, action) async {
            if (action == TriggerAction.view) views.add(id);
          },
        ),
      ),
    );
    await _pumpFrames(tester);
    session.fire('P01');
    await _pumpFrames(tester);
    _events(services).clear();

    await tester.ensureVisible(find.text('Lihat'));
    await tester.tap(find.text('Lihat'));
    await _pumpFrames(tester);
    expect(find.byType(PoiDetailScreen), findsOneWidget);

    expect(_events(services), isEmpty);
    await session.end();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
