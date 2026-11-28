import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_lb_services.dart';
import 'package:agam/logic/map/agam_map_config.dart';
import 'package:agam/ui/app.dart';
import 'package:agam/ui/poi_detail_screen.dart';
import 'package:agam/ui/search_route_screen.dart';
import 'package:agam/ui/walking_navigation_screen.dart';
import 'package:agam/ui/widgets/agam_components.dart';
import 'package:agam/ui/widgets/agam_motion.dart';
import 'package:agam/ui/widgets/offline_campus_map.dart';
import 'package:agam/ui/widgets/trip_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _opacityOf(WidgetTester tester, Finder child) => tester
    .widget<Opacity>(find.ancestor(of: child, matching: find.byType(Opacity)))
    .opacity;

void main() {
  testWidgets('two tabs; search on the map; settings behind the account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: AgamMainShell(
          services: AppServices.fake(tick: const Duration(hours: 1)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jelajah'), findsOneWidget);
    expect(find.text('Trail'), findsOneWidget);
    expect(find.text('Cari & Rute'), findsNothing);
    expect(find.text('Pengaturan'), findsNothing);
    // The search bar on the map opens the search page with the field ready.
    await tester.tap(find.text('Cari gedung atau fasilitas'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    // A facility chip opens the same page with that category filtering.
    await tester.tap(find.text('Musala'));
    await tester.pumpAndSettle();
    expect(find.text('Data musala belum tersedia.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profil & pengaturan'));
    await tester.pumpAndSettle();
    expect(find.text('Profil Pengguna'), findsOneWidget);
    expect(find.text('Fakultas / Sekolah'), findsNothing);
    expect(find.text('Notifikasi & izin aplikasi'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Profil Pengguna'), findsNothing);
    expect(find.text('Jelajah'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Rute sits on the map, search card and detail; demo routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = AppServices.fake(tick: const Duration(hours: 1));
    // SYNTHETIC: a fix already in memory, so "Rute" need not wait for GPS.
    final location = _HeldLocation(
      LocationFix(
        position: const GeoPoint(-6.8905, 107.6100),
        accuracyM: 5,
        timestamp: DateTime(2026),
      ),
    );
    // The fake map points at placeholder tiles; markers need the real ones.
    final services = AppServices(
      permissions: fake.permissions,
      location: location,
      pois: fake.pois,
      session: fake.session,
      audio: fake.audio,
      voice: fake.voice,
      settings: fake.settings,
      auth: fake.auth,
      activity: fake.activity,
      map: AgamMapConfig.campus(),
      routing: fake.routing,
      navigation: FakeNavigationController(
        location: location,
        routing: fake.routing,
      ),
      search: fake.search,
      recommendations: fake.recommendations,
      trail: fake.trail,
      facilities: fake.facilities,
    );
    await tester.pumpWidget(
      MaterialApp(home: AgamMainShell(services: services)),
    );
    // Real tiles decode off the test clock; wait for the map to appear.
    for (
      var frame = 0;
      frame < 200 &&
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      frame++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    // Map: the POI card.
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Buka Labtek V',
      ),
    );
    await tester.pumpAndSettle();
    // The map card opens the route preview directly, without the search
    // page; nothing starts until "Mulai rute".
    await tester.tap(find.text('Rute'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchRouteScreen), findsNothing);
    expect(find.byType(WalkingNavigationScreen), findsOneWidget);
    expect(find.text(WalkingNavigationScreen.startLabel), findsOneWidget);
    expect(services.session.current.mode, SessionMode.none);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    // The map card's detail: its Rute also lands on the preview directly.
    await tester.tap(find.text('Lihat'));
    await tester.pumpAndSettle();
    expect(find.byType(PoiDetailScreen), findsOneWidget);
    await tester.tap(find.text('Rute'));
    await tester.pumpAndSettle();
    expect(find.byType(PoiDetailScreen), findsNothing);
    expect(find.byType(SearchRouteScreen), findsNothing);
    expect(find.byType(WalkingNavigationScreen), findsOneWidget);
    expect(services.session.current.mode, SessionMode.none);
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tutup informasi'));
    await tester.pumpAndSettle();
    // Search: the destination card.
    await tester.tap(find.text('Cari gedung atau fasilitas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'labtek 5');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Labtek V').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Rute'));
    await tester.pumpAndSettle();
    // The search card routes on the bundled graph in the demo too.
    await tester.tap(find.text('Rute'));
    await tester.pumpAndSettle();
    expect(services.session.current.mode, SessionMode.none);
    await tester.tap(find.text(WalkingNavigationScreen.startLabel));
    await tester.pumpAndSettle();
    expect(services.session.current.mode, SessionMode.navigation);
    expect(services.navigation.current.status, NavigationStatus.onRoute);
    expect(find.byType(WalkingNavigationScreen), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    final map = find.byType(OfflineCampusMap);
    expect(tester.getSize(map), const Size(430, 900));
    expect(
      tester.widget<OfflineCampusMap>(map).routePath,
      services.navigation.current.route!.path,
    );
    // The walking card stays short: the preview already said the access
    // point is approximate.
    expect(find.byType(TripStatusCard), findsOneWidget);
    expect(find.text('Tujuan perkiraan'), findsNothing);
    expect(find.textContaining('Rute menuju titik akses'), findsNothing);
    await tester.tap(find.byTooltip(TripStatusCard.endTooltip));
    // Stopping settles outside the fake clock, like the tile decoding above.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(services.session.current.mode, SessionMode.none);
    expect(find.byType(WalkingNavigationScreen), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'labtek 5',
    );
    // Detail: the bottom action.
    await tester.ensureVisible(find.text('Lihat Detail POI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat Detail POI'));
    await tester.pumpAndSettle();
    // Rute on the detail closes it and opens the preview; Mulai starts it.
    await tester.tap(find.text('Rute'));
    await tester.pumpAndSettle();
    expect(find.byType(PoiDetailScreen), findsNothing);
    expect(find.byType(WalkingNavigationScreen), findsOneWidget);
    expect(services.session.current.mode, SessionMode.none);
    await tester.tap(find.text(WalkingNavigationScreen.startLabel));
    await tester.pumpAndSettle();
    expect(services.session.current.mode, SessionMode.navigation);
    expect(services.navigation.current.status, NavigationStatus.onRoute);
    // Stopping settles outside the fake clock, like the tile decoding above.
    await tester.runAsync(() async {
      await services.navigation.stop();
      await services.session.end();
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'reveal waits for play, plays once, and rests on reduced motion',
    (tester) async {
      Widget reveal({required bool play, bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: AgamReveal(play: play, child: const Text('Isi')),
        ),
      );
      await tester.pumpWidget(reveal(play: false));
      await tester.pump(const Duration(seconds: 1));
      expect(_opacityOf(tester, find.text('Isi')), 0);
      await tester.pumpWidget(reveal(play: true));
      await tester.pump(const Duration(milliseconds: 60));
      final midway = _opacityOf(tester, find.text('Isi'));
      expect(midway, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, find.text('Isi')), 1);
      // Leaving and re-entering the tab must not replay the entrance.
      await tester.pumpWidget(reveal(play: false));
      await tester.pumpWidget(reveal(play: true));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_opacityOf(tester, find.text('Isi')), 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(reveal(play: true, reduced: true));
      await tester.pump();
      expect(_opacityOf(tester, find.text('Isi')), 1);
    },
  );

  testWidgets('segmented control reports the tapped segment', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AgamSegmented(
              labels: const ['Semua', 'Belum', 'Selesai'],
              selected: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );
    final thumb = find.byType(AnimatedPositioned);
    final start = tester.getRect(thumb).left;
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(tester.getRect(thumb).left, greaterThan(start));
    expect(
      tester.getRect(thumb).center.dx,
      closeTo(tester.getCenter(find.text('Selesai')).dx, 1),
    );
  });

  group('TripStatusCard', () {
    // SINTETIS: a fixed clock so the arrival time is deterministic.
    DateTime clock() => DateTime(2026, 11, 28, 9, 22, 10);

    Future<void> pumpCard(
      WidgetTester tester, {
      String destination = 'Gedung uji (SINTETIS)',
      double? distance,
      Duration? eta,
      String? hint,
      bool isApproximate = false,
      VoidCallback? onEnd,
      Size size = const Size(430, 900),
      double textScale = 1,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TripStatusCard(
                    destination: destination,
                    remainingDistanceM: distance,
                    remainingEta: eta,
                    isApproximate: isApproximate,
                    locationHint: hint,
                    onEnd: onEnd ?? () {},
                    clock: clock,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('minutes as the hero, distance and arrival clock below', (
      tester,
    ) async {
      var ended = 0;
      await pumpCard(
        tester,
        distance: 126,
        eta: const Duration(seconds: 120),
        onEnd: () => ended++,
      );
      expect(find.text('2 menit'), findsOneWidget);
      // 09.22.10 + 2 minutes, in the Indonesian 24-hour dot format.
      expect(find.text('126 m · Tiba 09.24'), findsOneWidget);
      expect(find.text('Gedung uji (SINTETIS)'), findsOneWidget);
      expect(find.byIcon(Icons.place_rounded), findsOneWidget);
      expect(find.textContaining('Sisa'), findsNothing);
      expect(find.textContaining('~'), findsNothing);
      expect(find.bySemanticsLabel('Perkiraan 2 menit lagi'), findsOneWidget);

      expect(find.text(TripStatusCard.endLabel), findsOneWidget);
      final pill = tester.getSize(find.byType(FilledButton));
      expect(pill.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byTooltip(TripStatusCard.endTooltip));
      expect(ended, 1);
    });

    testWidgets('under a minute, kilometres with a decimal comma', (
      tester,
    ) async {
      await pumpCard(tester, distance: 1240, eta: const Duration(seconds: 34));
      expect(find.text('< 1 menit'), findsOneWidget);
      expect(find.bySemanticsLabel('Kurang dari 1 menit lagi'), findsOneWidget);
      expect(find.text('1,2 km · Tiba 09.22'), findsOneWidget);
    });

    testWidgets('no made-up numbers before the route has them', (tester) async {
      await pumpCard(tester);
      expect(find.text(TripStatusCard.calculatingLabel), findsOneWidget);
      expect(find.text(TripStatusCard.waitingLabel), findsOneWidget);
      expect(find.textContaining('menit'), findsNothing);

      await pumpCard(tester, distance: 80);
      expect(find.text(TripStatusCard.calculatingLabel), findsOneWidget);
      expect(find.text('80 m'), findsOneWidget);
    });

    testWidgets('never shows "Tujuan perkiraan" while walking', (tester) async {
      await pumpCard(
        tester,
        distance: 126,
        eta: const Duration(minutes: 2),
        isApproximate: true,
      );
      expect(find.text('Tujuan perkiraan'), findsNothing);
    });

    testWidgets('an indoor facility keeps its hint under the destination', (
      tester,
    ) async {
      // SINTETIS: test data, not campus content.
      const hint = 'Di dalam gedung uji, lantai 3';
      await pumpCard(
        tester,
        distance: 126,
        eta: const Duration(minutes: 2),
        hint: hint,
      );
      expect(find.text(hint), findsOneWidget);
      expect(find.byIcon(Icons.meeting_room_rounded), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(hint)).dy,
        greaterThan(tester.getTopLeft(find.text('Gedung uji (SINTETIS)')).dy),
      );
    });

    testWidgets('long names fit at 320 dp and 1.4x text', (tester) async {
      // SINTETIS: a deliberately long name to test wrapping.
      const longName =
          'Gedung uji dengan nama yang sangat panjang sekali untuk menguji '
          'dua baris tanpa luapan teks di layar sempit (SINTETIS)';
      await pumpCard(
        tester,
        destination: longName,
        distance: 1240,
        eta: const Duration(minutes: 125),
        hint:
            'Di dalam gedung uji dengan petunjuk panjang, lantai 3 (SINTETIS)',
        size: const Size(320, 640),
        textScale: 1.4,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('125 menit'), findsOneWidget);
      final name = tester.widget<Text>(find.text(longName));
      expect(name.maxLines, 2);
      expect(name.overflow, TextOverflow.ellipsis);
      final card = tester.getRect(find.byType(TripStatusCard));
      expect(card.width, lessThanOrEqualTo(320));
      expect(
        tester.getRect(find.byType(FilledButton)).right,
        lessThanOrEqualTo(card.right),
      );
      expect(find.text('Akhiri'), findsOneWidget);
    });
  });
}

class _HeldLocation implements LocationService {
  _HeldLocation(this.lastFix);

  @override
  final LocationFix? lastFix;

  final _positions = StreamController<LocationFix>.broadcast();

  @override
  Stream<LocationFix> get positions => _positions.stream;
}
