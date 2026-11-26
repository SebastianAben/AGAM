import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_data.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/contracts/fakes/fake_lb_services.dart';
import 'package:agam/logic/routing/route_planner.dart';
import 'package:agam/ui/poi_detail_screen.dart';
import 'package:agam/ui/search_route_screen.dart';
import 'package:agam/ui/walking_navigation_screen.dart';
import 'package:agam/ui/widgets/agam_motion.dart';
import 'package:agam/ui/widgets/agam_theme.dart';
import 'package:agam/ui/widgets/offline_campus_map.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS: POI/fasilitas palsu, posisi, sesi, rute, dan audio palsu.

class _Location implements LocationService {
  _Location([this._lastFix]);

  LocationFix? _lastFix;
  final _positions = StreamController<LocationFix>.broadcast();

  @override
  LocationFix? get lastFix => _lastFix;

  @override
  Stream<LocationFix> get positions => _positions.stream;

  void emit(LocationFix fix) {
    _lastFix = fix;
    _positions.add(fix);
  }
}

class _Session implements SessionController {
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

class _ThrowingRouting implements RoutingService {
  _ThrowingRouting(this.error);

  final RouteUnavailableException error;

  @override
  Future<WalkingRoute> route({
    required GeoPoint from,
    required GeoPoint to,
  }) async => throw error;
}

/// A route whose second step enters an unverified passage, worded as the
/// campus routing service words it.
class _PassageRouting implements RoutingService {
  @override
  Future<WalkingRoute> route({
    required GeoPoint from,
    required GeoPoint to,
  }) async => WalkingRoute(
    path: [from, to],
    distanceM: 80,
    eta: const Duration(seconds: 62),
    steps: [
      RouteStep(
        maneuver: Maneuver.depart,
        instruction: 'Ikuti jalur pejalan kaki.',
        distanceM: 40,
        position: from,
      ),
      RouteStep(
        maneuver: Maneuver.turnRight,
        instruction:
            'Belok kanan, lewat lorong dalam gedung '
            '(belum diverifikasi).',
        distanceM: 40,
        position: to,
      ),
    ],
  );
}

class _RecordingAudio extends FakeAudioService {
  int pauses = 0;
  int stops = 0;

  @override
  Future<void> pause() {
    pauses++;
    return super.pause();
  }

  @override
  Future<void> stop() {
    stops++;
    return super.stop();
  }
}

LocationFix _fixAt(GeoPoint point, {double accuracy = 5}) => LocationFix(
  position: point,
  accuracyM: accuracy,
  timestamp: DateTime.utc(2026),
);

final _here = fakePois.first;
final _there = fakePois[2];

AppServices _services({
  required LocationService location,
  RoutingService? routing,
  AudioService? audio,
  SessionController? session,
}) {
  final fake = AppServices.fake(tick: const Duration(hours: 1));
  final routes = routing ?? fake.routing;
  return AppServices(
    permissions: fake.permissions,
    location: location,
    pois: fake.pois,
    session: session ?? _Session(),
    audio: audio ?? fake.audio,
    voice: fake.voice,
    settings: fake.settings,
    auth: fake.auth,
    activity: FakeActivityLogger(),
    map: fake.map,
    routing: routes,
    navigation: FakeNavigationController(location: location, routing: routes),
    search: fake.search,
    recommendations: fake.recommendations,
    trail: fake.trail,
    facilities: fake.facilities,
  );
}

Future<void> _frames(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The fake navigation awaits a stream cancel that resolves outside the
/// fake clock, so stopping needs a few real milliseconds.
Future<void> _settleStop(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await _frames(tester, 3);
  }
}

void _phone(WidgetTester tester, {double width = 390}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A page with one button that opens the route preview, like Rute does.
Future<void> _openPreview(
  WidgetTester tester,
  AppServices services, {
  NavigationTarget? target,
  bool reduceMotion = false,
}) async {
  _phone(tester);
  await tester.pumpWidget(
    MaterialApp(
      // Above the navigator, so pushed pages see it too.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => WalkingNavigationScreen.open(
                context,
                services: services,
                target: target ?? NavigationTarget.poi(_there),
              ),
              child: const Text('Buka rute'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Buka rute'));
  await _frames(tester);
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

List<GeoPoint> _visiblePath(WidgetTester tester) => tester
    .widget<OfflineCampusMap>(
      find.descendant(
        of: find.byType(WalkingNavigationScreen),
        matching: find.byType(OfflineCampusMap),
      ),
    )
    .routePath;

void main() {
  // A map loads its style through rootBundle inside one test's fake zone;
  // a cached future from that zone would never resolve in the next test.
  tearDown(rootBundle.clear);

  testWidgets('preview shows the route before any session starts', (
    tester,
  ) async {
    final services = _services(location: _Location(_fixAt(_here.position)));
    await _openPreview(tester, services);

    expect(find.byType(WalkingNavigationScreen), findsOneWidget);
    expect(services.session.current.mode, SessionMode.none);
    expect(services.navigation.current.status, NavigationStatus.idle);
    // The planned route is drawn and summarised.
    final distance = _here.position.distanceTo(_there.navigationPoint);
    expect(_visiblePath(tester), hasLength(2));
    expect(find.textContaining('${distance.round()} m · ~'), findsOneWidget);
    expect(find.textContaining('jalan kaki'), findsOneWidget);
    // Fake POIs have no surveyed access point.
    expect(find.text('Tujuan perkiraan'), findsOneWidget);
    expect(find.text(WalkingNavigationScreen.startLabel), findsOneWidget);
    expect(find.text('Akhiri rute'), findsNothing);

    // Back from the preview leaves nothing running.
    await tester.tap(find.byTooltip('Kembali'));
    await _frames(tester);
    expect(find.byType(WalkingNavigationScreen), findsNothing);
    expect(services.session.current.mode, SessionMode.none);
    await _tearDown(tester);
  });

  testWidgets('Mulai rute pauses the narration and starts navigation', (
    tester,
  ) async {
    final audio = _RecordingAudio();
    final services = _services(
      location: _Location(_fixAt(_here.position)),
      audio: audio,
    );
    await audio.play(AudioClip(poiId: _here.id, kind: AudioClipKind.narration));
    expect(audio.current.status, PlaybackStatus.playing);
    await _openPreview(tester, services);

    await tester.tap(find.text(WalkingNavigationScreen.startLabel));
    await _frames(tester);
    // Two voices never play together: paused, not stopped (PRD §10).
    expect(audio.pauses, 1);
    expect(audio.stops, 0);
    expect(audio.current.status, PlaybackStatus.paused);
    expect(services.session.current.mode, SessionMode.navigation);
    expect(services.navigation.current.status, NavigationStatus.onRoute);
    expect(services.navigation.current.target?.id, _there.id);
    // Same map, now walking: the instruction panel and the trip card.
    expect(find.byType(OfflineCampusMap), findsOneWidget);
    expect(_visiblePath(tester), services.navigation.current.route!.path);
    expect(find.textContaining('Berjalan lurus'), findsOneWidget);
    expect(find.textContaining('Sisa '), findsOneWidget);
    expect(find.text(WalkingNavigationScreen.startLabel), findsNothing);

    await tester.tap(find.text('Akhiri rute'));
    await _settleStop(tester);
    expect(find.byType(WalkingNavigationScreen), findsNothing);
    expect(services.session.current.mode, SessionMode.none);
    expect(services.navigation.current.status, NavigationStatus.idle);
    await _tearDown(tester);
  });

  testWidgets('arrival shows UI07 on the same map; a recommendation opens '
      'its preview without a session', (tester) async {
    final location = _Location(_fixAt(_here.position));
    final services = _services(location: location);
    await _openPreview(tester, services);
    await tester.tap(find.text(WalkingNavigationScreen.startLabel));
    await _frames(tester);
    location.emit(_fixAt(_there.navigationPoint));
    await _frames(tester);
    expect(services.navigation.current.status, NavigationStatus.arrived);
    expect(find.text('Anda telah tiba di ${_there.name}'), findsOneWidget);
    expect(find.text('Akhiri rute'), findsNothing);
    final next = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'recommendation-route-',
          ),
    );
    expect(next, findsWidgets);
    final id = (tester.widget(next.first).key! as ValueKey<String>).value
        .replaceFirst('recommendation-route-', '');
    await tester.ensureVisible(next.first);
    await tester.tap(next.first);
    await _settleStop(tester);
    expect(find.byType(WalkingNavigationScreen), findsOneWidget);
    expect(services.session.current.mode, SessionMode.none);
    expect(find.text(WalkingNavigationScreen.startLabel), findsOneWidget);
    final poi = fakePois.firstWhere((p) => p.id == id);
    expect(find.text(poi.name), findsWidgets);
    await _tearDown(tester);
  });

  testWidgets('a route through an unverified passage says so', (tester) async {
    final services = _services(
      location: _Location(_fixAt(_here.position)),
      routing: _PassageRouting(),
    );
    await _openPreview(tester, services);
    expect(find.text(WalkingNavigationScreen.passageNote), findsOneWidget);
    // 62 s rounds up to two minutes.
    expect(find.text('80 m · ~2 menit jalan kaki'), findsOneWidget);
    await _tearDown(tester);
  });

  testWidgets('an outdoor route has no passage note', (tester) async {
    final services = _services(location: _Location(_fixAt(_here.position)));
    await _openPreview(tester, services);
    expect(find.text(WalkingNavigationScreen.passageNote), findsNothing);
    await _tearDown(tester);
  });

  testWidgets('no narration playing: Mulai rute pauses nothing', (
    tester,
  ) async {
    final audio = _RecordingAudio();
    final services = _services(
      location: _Location(_fixAt(_here.position)),
      audio: audio,
    );
    await _openPreview(tester, services);
    await tester.tap(find.text(WalkingNavigationScreen.startLabel));
    await _frames(tester);
    expect(audio.pauses, 0);
    expect(services.session.current.mode, SessionMode.navigation);
    await _tearDown(tester);
  });

  group('per-cause messages before the session starts', () {
    testWidgets('no fix yet: says so, then plans on the first fix', (
      tester,
    ) async {
      final location = _Location();
      final services = _services(location: location);
      await _openPreview(tester, services);
      expect(
        find.text(
          WalkingNavigationScreen.problemMessage(RouteProblem.locating),
        ),
        findsOneWidget,
      );
      expect(services.session.current.mode, SessionMode.none);
      // An inaccurate fix is not enough either.
      location.emit(_fixAt(_here.position, accuracy: 60));
      await _frames(tester, 3);
      expect(
        find.text(
          WalkingNavigationScreen.problemMessage(RouteProblem.locating),
        ),
        findsOneWidget,
      );
      location.emit(_fixAt(_here.position));
      await _frames(tester, 3);
      expect(
        find.text(
          WalkingNavigationScreen.problemMessage(RouteProblem.locating),
        ),
        findsNothing,
      );
      expect(_visiblePath(tester), hasLength(2));
      expect(find.text(WalkingNavigationScreen.startLabel), findsOneWidget);
      await _tearDown(tester);
    });

    testWidgets('outside campus: the PRD §9.3 message', (tester) async {
      final location = _Location(_fixAt(const GeoPoint(-6.95, 107.70)));
      final services = _services(location: location);
      await _openPreview(tester, services);
      final message = WalkingNavigationScreen.problemMessage(
        RouteProblem.outsideCampus,
      );
      expect(message, startsWith('Anda berada di luar area Kampus Ganesha'));
      expect(find.text(message), findsOneWidget);
      expect(_visiblePath(tester), isEmpty);
      // Walking into campus brings the route without a tap.
      location.emit(_fixAt(_here.position));
      await _frames(tester, 3);
      expect(find.text(message), findsNothing);
      expect(_visiblePath(tester), hasLength(2));
      await _tearDown(tester);
    });

    testWidgets('too far from a path: says so and offers a retry', (
      tester,
    ) async {
      final services = _services(
        location: _Location(_fixAt(_here.position)),
        routing: _ThrowingRouting(const RouteStartOffNetworkException()),
      );
      await _openPreview(tester, services);
      expect(
        find.text(
          WalkingNavigationScreen.problemMessage(RouteProblem.offNetwork),
        ),
        findsOneWidget,
      );
      expect(find.text(WalkingNavigationScreen.retryLabel), findsOneWidget);
      expect(find.text(WalkingNavigationScreen.startLabel), findsNothing);
      expect(services.session.current.mode, SessionMode.none);
      await _tearDown(tester);
    });

    testWidgets('any other failure: the route is not available', (
      tester,
    ) async {
      final services = _services(
        location: _Location(_fixAt(_here.position)),
        routing: _ThrowingRouting(
          const RouteUnavailableException('Tidak ada rute.'),
        ),
      );
      await _openPreview(tester, services);
      expect(
        find.text('Rute belum tersedia untuk tujuan ini.'),
        findsOneWidget,
      );
      expect(find.text(WalkingNavigationScreen.retryLabel), findsOneWidget);
      expect(services.session.current.mode, SessionMode.none);
      await _tearDown(tester);
    });
  });

  testWidgets('a facility from search shows its name and distance, then '
      'opens its preview', (tester) async {
    _phone(tester);
    final facility = fakeFacilities.first;
    final services = _services(location: _Location(_fixAt(_here.position)));
    await tester.pumpWidget(
      MaterialApp(home: SearchRouteScreen(services: services)),
    );
    await _frames(tester, 4);
    await tester.enterText(find.byType(TextField), facility.name);
    await _frames(tester, 4);
    await tester.tap(find.text(facility.name).last);
    await _frames(tester, 6);
    expect(find.text('Pencarian fasilitas belum tersedia.'), findsNothing);
    expect(find.text('Informasi gedung belum tersedia.'), findsNothing);
    expect(find.textContaining('dari posisi Anda'), findsOneWidget);
    final route = find.widgetWithText(FilledButton, 'Rute').first;
    await tester.ensureVisible(route);
    await _frames(tester, 2);
    await tester.tap(route);
    await _frames(tester);
    expect(find.byType(WalkingNavigationScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(WalkingNavigationScreen),
        matching: find.text(facility.name),
      ),
      findsOneWidget,
    );
    expect(services.session.current.mode, SessionMode.none);
    await _tearDown(tester);
  });

  testWidgets('Rute on a POI detail opens the preview, not the search page', (
    tester,
  ) async {
    // The detail's audio time row overflows at 390 wide without a clip
    // (outside this package); 430 as in the other detail tests.
    _phone(tester, width: 430);
    final services = _services(location: _Location(_fixAt(_here.position)));
    await tester.pumpWidget(
      MaterialApp(
        home: SearchRouteScreen(services: services, initialDestination: _there),
      ),
    );
    await _frames(tester, 4);
    await tester.ensureVisible(find.text('Lihat Detail POI'));
    await tester.tap(find.text('Lihat Detail POI'));
    await _frames(tester, 6);
    expect(find.byType(PoiDetailScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Rute'));
    await _frames(tester, 8);
    expect(find.byType(PoiDetailScreen), findsNothing);
    expect(find.byType(WalkingNavigationScreen), findsOneWidget);
    expect(services.session.current.mode, SessionMode.none);
    await _tearDown(tester);
  });

  testWidgets('pushed pages fade over the canvas, never black', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                Navigator.of(context)
                    .push(AgamMotion.route<void>((_) => const Text('Halaman'))),
            child: const Text('Buka'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final transitions = tester.widgetList<SharedAxisTransition>(
      find.byType(SharedAxisTransition),
    );
    expect(transitions, isNotEmpty);
    for (final transition in transitions) {
      expect(transition.fillColor, AgamColors.canvas);
      expect(transition.fillColor, isNot(Colors.transparent));
    }
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion: preview, start and end without errors', (
    tester,
  ) async {
    final services = _services(location: _Location(_fixAt(_here.position)));
    await _openPreview(tester, services, reduceMotion: true);
    expect(find.text(WalkingNavigationScreen.startLabel), findsOneWidget);
    await tester.tap(find.text(WalkingNavigationScreen.startLabel));
    await _frames(tester, 3);
    expect(services.session.current.mode, SessionMode.navigation);
    expect(find.text('Akhiri rute'), findsOneWidget);
    await tester.tap(find.text('Akhiri rute'));
    await _settleStop(tester);
    expect(find.byType(WalkingNavigationScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await _tearDown(tester);
  });
}
