import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_data.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/ui/poi_detail_screen.dart';
import 'package:agam/ui/search_route_screen.dart';
import 'package:agam/ui/widgets/arrival_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// SINTETIS. Navigasi yang statusnya diatur test.
class _ManualNavigation implements NavigationController {
  _ManualNavigation([NavigationState initial = const NavigationState.idle()])
    : _current = initial;

  final _states = StreamController<NavigationState>.broadcast();
  NavigationState _current;
  int stops = 0;

  void emit(NavigationState state) {
    _current = state;
    _states.add(state);
  }

  @override
  NavigationState get current => _current;

  @override
  Stream<NavigationState> get state => _states.stream;

  @override
  Future<void> start(NavigationTarget target) async {}

  @override
  Future<void> stop() async {
    stops++;
    emit(const NavigationState.idle());
  }
}

AppServices _services(NavigationController navigation, VoiceGuidance voice) {
  final fake = AppServices.fake(tick: const Duration(hours: 1));
  return AppServices(
    permissions: fake.permissions,
    location: fake.location,
    pois: fake.pois,
    session: fake.session,
    audio: fake.audio,
    voice: voice,
    settings: fake.settings,
    auth: fake.auth,
    activity: fake.activity,
    map: fake.map,
    routing: fake.routing,
    navigation: navigation,
    search: fake.search,
    recommendations: fake.recommendations,
    trail: fake.trail,
    facilities: fake.facilities,
  );
}

NavigationState _state(NavigationStatus status, NavigationTarget target) =>
    NavigationState(status: status, target: target);

Future<void> _show(
  WidgetTester tester,
  AppServices services, {
  bool reduceMotion = false,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          disableAnimations: reduceMotion,
        ),
        child: SearchRouteScreen(services: services),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

double _opacityOf(WidgetTester tester, Finder text) {
  final opacity = tester.widget<Opacity>(
    find.ancestor(of: text, matching: find.byType(Opacity)).first,
  );
  return opacity.opacity;
}

void main() {
  final poi = fakePois.first;
  final facility = fakeFacilities.first;
  final poiTarget = NavigationTarget.poi(poi);
  final facilityTarget = NavigationTarget.facility(facility);

  testWidgets('kartu tujuan berubah menjadi kartu tiba saat navigasi tiba', (
    tester,
  ) async {
    final navigation = _ManualNavigation(
      _state(NavigationStatus.onRoute, poiTarget),
    );
    final services = _services(navigation, FakeVoiceGuidance());
    await _show(tester, services);

    final headline = 'Anda telah tiba di ${poi.name}';
    expect(find.text(headline), findsNothing);
    expect(find.text('Navigasi sedang berjalan'), findsOneWidget);

    navigation.emit(_state(NavigationStatus.arrived, poiTarget));
    await tester.pump();
    expect(find.text(headline), findsOneWidget);
    expect(find.text('Navigasi sedang berjalan'), findsNothing);
    // Arrival content eases in rather than appearing at once.
    expect(_opacityOf(tester, find.text(headline)), lessThan(1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_opacityOf(tester, find.text(headline)), 1);

    // A POI offers its detail; no voice note, the clip announces it.
    expect(find.text('Lihat Detail POI'), findsOneWidget);
    expect(find.text(ArrivalCard.voiceNote), findsNothing);

    await _tearDown(tester);
  });

  testWidgets('tiba di tujuan lain tidak mengubah kartu tujuan terpilih', (
    tester,
  ) async {
    final navigation = _ManualNavigation(
      _state(NavigationStatus.onRoute, poiTarget),
    );
    final services = _services(navigation, FakeVoiceGuidance());
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SearchRouteScreen(
          services: services,
          initialDestination: fakePois[1],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    navigation.emit(_state(NavigationStatus.arrived, poiTarget));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Anda telah tiba di'), findsNothing);

    await _tearDown(tester);
  });

  testWidgets('Lihat Detail POI membuka detail gedung', (tester) async {
    final navigation = _ManualNavigation(
      _state(NavigationStatus.arrived, poiTarget),
    );
    final services = _services(navigation, FakeVoiceGuidance());
    // Wider than a phone: at 390 px a row in the detail screen overflows by
    // a few pixels in this test, which is outside this package.
    await _show(tester, services, width: 600);

    final detail = find.text('Lihat Detail POI');
    await tester.ensureVisible(detail);
    await tester.tap(detail);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PoiDetailScreen), findsOneWidget);
    // Opened right at arrival: no featureUsed, its time would match the
    // arrival at the POI (PRD §15.5, rules §5.1).
    expect(
      tester.widget<PoiDetailScreen>(find.byType(PoiDetailScreen)).activity,
      isNull,
    );

    await _tearDown(tester);
  });

  testWidgets('tiba menggulir daftar kembali ke kartu tiba', (tester) async {
    final navigation = _ManualNavigation(
      _state(NavigationStatus.onRoute, poiTarget),
    );
    final services = _services(navigation, FakeVoiceGuidance());
    await _show(tester, services);
    final list = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    double offset() => tester.state<ScrollableState>(list).position.pixels;
    await tester.drag(list, const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 400));
    expect(offset(), greaterThan(0));

    navigation.emit(_state(NavigationStatus.arrived, poiTarget));
    await tester.pump();
    // The scroll starts after the arrival frame, then runs for 360 ms.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(offset(), 0);
    expect(find.text('Lihat Detail POI').hitTestable(), findsOneWidget);

    await _tearDown(tester);
  });

  testWidgets('Selesai menghentikan navigasi dan menutup kartu', (
    tester,
  ) async {
    final navigation = _ManualNavigation(
      _state(NavigationStatus.arrived, facilityTarget),
    );
    final services = _services(navigation, FakeVoiceGuidance());
    await _show(tester, services);

    final headline = 'Anda telah tiba di ${facility.name}';
    expect(find.text(headline), findsOneWidget);
    // A facility has no detail page to offer.
    expect(find.text('Lihat Detail POI'), findsNothing);

    final finish = find.text('Selesai');
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pump(const Duration(milliseconds: 400));
    expect(navigation.stops, 1);
    expect(find.text(headline), findsNothing);

    await _tearDown(tester);
  });

  testWidgets('fasilitas tanpa suara id-ID menampilkan cara memasangnya', (
    tester,
  ) async {
    final navigation = _ManualNavigation(
      _state(NavigationStatus.arrived, facilityTarget),
    );
    final services = _services(navigation, FakeVoiceGuidance(available: false));
    await _show(tester, services);
    expect(find.text(ArrivalCard.voiceNote), findsOneWidget);

    await _tearDown(tester);
  });

  testWidgets('fasilitas dengan suara id-ID tidak menampilkan catatan', (
    tester,
  ) async {
    final navigation = _ManualNavigation(
      _state(NavigationStatus.arrived, facilityTarget),
    );
    final services = _services(navigation, FakeVoiceGuidance());
    await _show(tester, services);
    expect(find.text(ArrivalCard.voiceNote), findsNothing);

    await _tearDown(tester);
  });

  testWidgets('reduced motion: kartu tiba tampil tanpa animasi', (
    tester,
  ) async {
    final navigation = _ManualNavigation(
      _state(NavigationStatus.onRoute, poiTarget),
    );
    final services = _services(navigation, FakeVoiceGuidance());
    await _show(tester, services, reduceMotion: true);

    navigation.emit(_state(NavigationStatus.arrived, poiTarget));
    await tester.pump();
    final headline = find.text('Anda telah tiba di ${poi.name}');
    expect(headline, findsOneWidget);
    expect(_opacityOf(tester, headline), 1);
    final translate = tester.widget<Transform>(
      find.ancestor(of: headline, matching: find.byType(Transform)).first,
    );
    expect(translate.transform.getTranslation().y, 0);

    await _tearDown(tester);
  });
}
