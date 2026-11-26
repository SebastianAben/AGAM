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
          internalDemo: true,
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
      map: AgamMapConfig.internalDemo(),
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
      MaterialApp(home: AgamMainShell(services: services, internalDemo: true)),
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
    // The map card hands the POI to the search page as the destination.
    await tester.tap(find.text('Rute'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchRouteScreen), findsOneWidget);
    expect(find.text('Tutup pilihan'), findsOneWidget);
    expect(services.session.current.mode, SessionMode.none);
    await tester.tap(find.byTooltip('Back'));
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
    // Fake POIs have no verified access point.
    expect(find.text('Tujuan perkiraan'), findsOneWidget);
    expect(find.textContaining('Rute menuju titik akses'), findsNothing);
    await tester.tap(find.text('Akhiri rute'));
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
    // Rute on the detail closes it and starts the route from the search page.
    await tester.tap(find.text('Rute'));
    await tester.pumpAndSettle();
    expect(find.byType(PoiDetailScreen), findsNothing);
    expect(find.byType(WalkingNavigationScreen), findsOneWidget);
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
}

class _HeldLocation implements LocationService {
  _HeldLocation(this.lastFix);

  @override
  final LocationFix? lastFix;

  final _positions = StreamController<LocationFix>.broadcast();

  @override
  Stream<LocationFix> get positions => _positions.stream;
}
