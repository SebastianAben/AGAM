import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_data.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/ui/explore_map_screen.dart';
import 'package:agam/ui/search_route_screen.dart';
import 'package:agam/ui/widgets/recommendation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS: fake POIs/fasilitas, rekomendasi tetap, sesi dan lokasi palsu.

class _StubRecommendations implements RecommendationService {
  _StubRecommendations(this.result);

  final Recommendation result;
  final calls = <({GeoPoint from, String? afterPoiId})>[];

  @override
  Future<Recommendation> recommend({
    required GeoPoint from,
    String? afterPoiId,
  }) async {
    calls.add((from: from, afterPoiId: afterPoiId));
    return result;
  }
}

class _ManualNavigation implements NavigationController {
  _ManualNavigation(this._current);

  final _states = StreamController<NavigationState>.broadcast();
  NavigationState _current;
  final started = <NavigationTarget>[];

  void emit(NavigationState state) {
    _current = state;
    _states.add(state);
  }

  @override
  NavigationState get current => _current;

  @override
  Stream<NavigationState> get state => _states.stream;

  @override
  Future<void> start(NavigationTarget target) async {
    started.add(target);
    emit(NavigationState(status: NavigationStatus.onRoute, target: target));
  }

  @override
  Future<void> stop() async => emit(const NavigationState.idle());
}

class _Session implements SessionController {
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

class _StaticLocation implements LocationService {
  _StaticLocation(this.lastFix);
  @override
  final LocationFix? lastFix;
  @override
  Stream<LocationFix> get positions => const Stream.empty();
}

final _here = fakePois.first;
final _next = fakePois[1];
final _later = fakePois[2];

Recommendation _full() => Recommendation(
  poiIds: [_next.id, _later.id],
  nearbyFacilities: [
    FacilityDistance(facility: fakeFacilities[0], distanceM: 42),
    FacilityDistance(facility: fakeFacilities[1], distanceM: 1234),
  ],
);

AppServices _services({
  required RecommendationService recommendations,
  NavigationController? navigation,
  SessionController? session,
  LocationService? location,
}) {
  final fake = AppServices.fake(tick: const Duration(hours: 1));
  return AppServices(
    permissions: fake.permissions,
    location: location ?? fake.location,
    pois: fake.pois,
    session: session ?? _Session(),
    audio: fake.audio,
    voice: fake.voice,
    settings: fake.settings,
    auth: fake.auth,
    activity: FakeActivityLogger(),
    map: fake.map,
    routing: fake.routing,
    navigation: navigation ?? fake.navigation,
    search: fake.search,
    recommendations: recommendations,
    trail: fake.trail,
    facilities: fake.facilities,
  );
}

List<FeatureUsedEvent> _featureUsed(AppServices services) =>
    (services.activity as FakeActivityLogger).events
        .whereType<FeatureUsedEvent>()
        .toList();

void _phone(WidgetTester tester, {double height = 900, double width = 430}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The live map keeps animating, so pumpAndSettle would never return.
Future<void> _frames(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child,
    ),
  ),
);

final _card = find.byKey(const ValueKey('recommendation-card'));

Iterable<double> _opacities(WidgetTester tester) => tester
    .widgetList<Opacity>(
      find.ancestor(
        of: find.text(RecommendationCard.title),
        matching: find.byType(Opacity),
      ),
    )
    .map((o) => o.opacity);

LocationFix _fixAt(GeoPoint point) =>
    LocationFix(position: point, accuracyM: 5, timestamp: DateTime.utc(2026));

void main() {
  group('setelah tiba (halaman pencarian)', () {
    Future<(AppServices, _ManualNavigation)> arrive(
      WidgetTester tester,
      RecommendationService recommendations, {
      bool reduceMotion = false,
    }) async {
      _phone(tester, height: 1400);
      final target = NavigationTarget.poi(_here);
      final navigation = _ManualNavigation(
        NavigationState(status: NavigationStatus.onRoute, target: target),
      );
      final services = _services(
        recommendations: recommendations,
        navigation: navigation,
        location: _StaticLocation(_fixAt(_here.position)),
      );
      await tester.pumpWidget(
        _app(SearchRouteScreen(services: services), reduceMotion: reduceMotion),
      );
      await _frames(tester, 4);
      expect(_card, findsNothing);
      navigation.emit(
        NavigationState(status: NavigationStatus.arrived, target: target),
      );
      await tester.pump();
      await tester.pump();
      return (services, navigation);
    }

    testWidgets('halaman pencarian dari satu ketukan langsung memulai rute', (
      tester,
    ) async {
      _phone(tester, height: 1400);
      final navigation = _ManualNavigation(const NavigationState.idle());
      final services = _services(
        recommendations: _StubRecommendations(_full()),
        navigation: navigation,
        location: _StaticLocation(_fixAt(_here.position)),
      );
      await tester.pumpWidget(
        _app(
          SearchRouteScreen(
            services: services,
            initialDestination: _next,
            startRouteOnOpen: true,
          ),
        ),
      );
      await _frames(tester, 4);
      expect(navigation.started.single.id, _next.id);
      expect(services.session.current.mode, SessionMode.navigation);
      await tester.pumpWidget(const SizedBox.shrink());
      await _frames(tester, 2);
    });

    testWidgets('UI07 menampilkan POI dan fasilitas; Rute memulai navigasi', (
      tester,
    ) async {
      final recommendations = _StubRecommendations(_full());
      final (services, navigation) = await arrive(tester, recommendations);
      await _frames(tester, 4);

      expect(find.text(RecommendationCard.title), findsOneWidget);
      final call = recommendations.calls.single;
      expect(call.afterPoiId, _here.id);
      expect(call.from, _here.position);
      // The search results below list every POI too; look inside the card.
      Finder inCard(String text) =>
          find.descendant(of: _card, matching: find.text(text));
      expect(inCard(_next.name), findsOneWidget);
      expect(inCard(_later.name), findsOneWidget);
      expect(inCard(_here.name), findsNothing);
      // The first is the nearest; distance is an approximate straight line.
      expect(find.textContaining('Terdekat · ± '), findsOneWidget);
      expect(find.textContaining('Belum dikunjungi · ± '), findsOneWidget);
      expect(find.text('${fakeFacilities[0].name} · ± 40 m'), findsOneWidget);
      expect(find.text('${fakeFacilities[1].name} · ± 1,2 km'), findsOneWidget);

      final route = find.byKey(ValueKey('recommendation-route-${_next.id}'));
      await tester.ensureVisible(route);
      await tester.tap(route);
      await _frames(tester, 4);
      // One tap: the route to the recommended POI has started.
      expect(navigation.started.single.id, _next.id);
      expect(services.session.current.mode, SessionMode.navigation);
      expect(_card, findsNothing);
      // Shown right after arrival: nothing logged (PRD §15.5, rules §5.1).
      expect(_featureUsed(services), isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tanpa rekomendasi: pesan tenang, tanpa item palsu', (
      tester,
    ) async {
      final (services, _) = await arrive(
        tester,
        _StubRecommendations(
          const Recommendation(poiIds: [], nearbyFacilities: []),
        ),
      );
      await _frames(tester, 4);

      expect(find.text(RecommendationCard.emptyMessage), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'recommendation-route-',
              ),
        ),
        findsNothing,
      );
      expect(_featureUsed(services), isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('masuk dengan fade dan naik singkat', (tester) async {
      await arrive(tester, _StubRecommendations(_full()));
      expect(_card, findsOneWidget);
      expect(_opacities(tester).any((o) => o < 1), isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_opacities(tester).every((o) => o == 1), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('reduced motion: tampil tanpa animasi', (tester) async {
      await arrive(tester, _StubRecommendations(_full()), reduceMotion: true);
      expect(_card, findsOneWidget);
      expect(_opacities(tester).every((o) => o == 1), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('setelah panel POI ditutup (peta)', () {
    Future<(AppServices, _Session, List<Poi>)> openPanel(
      WidgetTester tester,
      _StubRecommendations recommendations, {
      bool reduceMotion = false,
      Size size = const Size(430, 900),
      bool searchBar = false,
    }) async {
      _phone(tester, width: size.width, height: size.height);
      final session = _Session();
      final services = _services(
        recommendations: recommendations,
        session: session,
        location: _StaticLocation(null),
      );
      final routed = <Poi>[];
      await session.start(SessionMode.explore);
      await tester.pumpWidget(
        _app(
          ExploreMapScreen(
            services: services,
            // The panel's Rute opens the destination card; a recommendation
            // starts the route in one tap (PRD F07).
            onRoute: (_) {},
            onStartRoute: routed.add,
            onOpenSearch: searchBar ? (_) {} : null,
          ),
          reduceMotion: reduceMotion,
        ),
      );
      await _frames(tester);
      session.fire(_here.id);
      await _frames(tester);
      expect(find.byTooltip('Tutup informasi'), findsOneWidget);
      return (services, session, routed);
    }

    testWidgets('menutup panel memunculkan UI07; Rute satu ketukan', (
      tester,
    ) async {
      final recommendations = _StubRecommendations(_full());
      final (services, _, routed) = await openPanel(tester, recommendations);
      expect(_card, findsNothing);

      await tester.tap(find.byTooltip('Tutup informasi'));
      await _frames(tester);
      expect(_card, findsOneWidget);
      // No fix on the map: measured from the closed POI, and said so.
      final call = recommendations.calls.single;
      expect(call.afterPoiId, _here.id);
      expect(call.from, _here.position);
      expect(find.textContaining('dari ${_here.name}'), findsWidgets);

      await tester.tap(
        find.byKey(ValueKey('recommendation-route-${_next.id}')),
      );
      await _frames(tester, 3);
      expect(routed.map((p) => p.id), [_next.id]);
      expect(_card, findsNothing);
      expect(_featureUsed(services), isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('kartu dapat ditutup dan hilang saat panel dibuka lagi', (
      tester,
    ) async {
      final (_, session, _) = await openPanel(
        tester,
        _StubRecommendations(_full()),
      );
      await tester.tap(find.byTooltip('Tutup informasi'));
      await _frames(tester);
      expect(_card, findsOneWidget);
      await tester.tap(find.byTooltip('Tutup rekomendasi'));
      await _frames(tester, 3);
      expect(_card, findsNothing);

      // A panel opening again replaces the card.
      session.fire(_here.id);
      await _frames(tester);
      await tester.tap(find.byTooltip('Tutup informasi'));
      await _frames(tester);
      expect(_card, findsOneWidget);
      session.fire(_next.id);
      await _frames(tester);
      expect(_card, findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('ponsel kecil: kartu tidak menutupi kontrol peta', (
      tester,
    ) async {
      // 360×640 minus the shell's bottom bar, with the search bar shown as
      // in the app, so the controls sit below it.
      await openPanel(
        tester,
        _StubRecommendations(
          Recommendation(
            poiIds: [_next.id, _later.id, fakePois[3].id],
            nearbyFacilities: _full().nearbyFacilities,
          ),
        ),
        size: const Size(360, 560),
        searchBar: true,
      );
      await tester.tap(find.byTooltip('Tutup informasi'));
      await _frames(tester);
      expect(_card, findsOneWidget);
      final controls = tester.getRect(
        find.byTooltip('Sembunyikan penanda POI'),
      );
      expect(tester.getRect(_card).top, greaterThan(controls.bottom));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Lewati menolak POI, tanpa rekomendasi', (tester) async {
      final recommendations = _StubRecommendations(_full());
      await openPanel(tester, recommendations);
      await tester.ensureVisible(find.text('Lewati'));
      await tester.tap(find.text('Lewati'));
      await _frames(tester);
      expect(_card, findsNothing);
      expect(recommendations.calls, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('reduced motion: tampil tanpa animasi', (tester) async {
      await openPanel(
        tester,
        _StubRecommendations(_full()),
        reduceMotion: true,
      );
      await tester.tap(find.byTooltip('Tutup informasi'));
      await tester.pump();
      await tester.pump();
      expect(_card, findsOneWidget);
      expect(_opacities(tester).every((o) => o == 1), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
