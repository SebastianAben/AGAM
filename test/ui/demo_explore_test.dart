import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/data/data.dart';
import 'package:agam/logic/location/device_location_service.dart';
import 'package:agam/logic/location/position_source.dart';
import 'package:agam/logic/map/agam_map_config.dart';
import 'package:agam/logic/session/device_session_controller.dart';
import 'package:agam/ui/app.dart';
import 'package:agam/ui/widgets/agam_bottom_navigation.dart';
import 'package:agam/logic/search/poi_search_service.dart';
import 'package:agam/logic/session/trigger_notifier.dart';
import 'package:agam/ui/poi_detail_screen.dart';
import 'package:agam/ui/widgets/offline_campus_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../logic/support/synthetic.dart';

void main() {
  testWidgets('unapproved synthetic POI keeps content and media unavailable', (
    tester,
  ) async {
    final services = AppServices.fake(tick: Duration.zero);
    final poi = (await services.pois.poiById('P01'))!;
    expect(poi.metadata.isPlaceholder, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: PoiDetailScreen(
          poi: poi,
          audio: services.audio,
          onNavigate: () async {},
          checkedIn: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Fungsi & Gambaran Gedung'), 250);
    await tester.pumpAndSettle();
    expect(find.textContaining('Informasi belum tersedia'), findsWidgets);
    expect(find.byType(Image), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Labtek V: real session dwell -> trigger -> same POI detail; view notification; stop',
    (tester) async {
      // SIMULASI pembacaan GPS pada koordinat resmi; bukan evidence perangkat.
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final oldShadows = debugDisableShadows;
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = oldShadows);
      await tester.runAsync(() async {
        await (FontLoader('PlusJakartaSans')..addFont(
              rootBundle.load('assets/fonts/PlusJakartaSans-Variable.ttf'),
            ))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      Future<void> drain(Future<void> future) async {
        var done = false;
        Object? failure;
        future.then(
          (_) => done = true,
          onError: (Object error) {
            failure = error;
            done = true;
          },
        );
        for (var i = 0; i < 100 && !done; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
          await tester.pump();
        }
        expect(done, isTrue, reason: 'Async stream cleanup must complete');
        if (failure != null) throw failure!;
      }

      final repository = PoiRepositoryImpl(
        bundled: const BundledDataset(),
        cache: InMemoryDatasetCache(),
      );
      await tester.runAsync(repository.ensureLoaded);
      final poi = (await tester.runAsync(() => repository.poiById('P01')))!;
      final source = RecordingPositionSource();
      final location = DeviceLocationService(source: source);
      final map = AgamMapConfig.internalDemo();
      final session = DeviceSessionController(
        location: location,
        pois: repository,
        isInsideCampus: map.isInsideCampus,
        trialModeAvailable: true,
      );
      final fake = AppServices.fake();
      final services = AppServices(
        permissions: fake.permissions,
        location: location,
        pois: repository,
        session: session,
        audio: fake.audio,
        voice: fake.voice,
        settings: fake.settings,
        auth: fake.auth,
        activity: fake.activity,
        map: map,
        routing: fake.routing,
        navigation: fake.navigation,
        search: PoiSearchService(pois: repository),
        recommendations: fake.recommendations,
        trail: fake.trail,
        facilities: fake.facilities,
      );
      final views = StreamController<String>.broadcast();
      final actions = <TriggerActionEvent>[];
      final repaint = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'PlusJakartaSans'),
          home: RepaintBoundary(
            key: repaint,
            child: AgamMainShell(
              services: services,
              internalDemo: true,
              poiViewRequests: views.stream,
              onPoiAction: (id, action) async {
                actions.add(TriggerActionEvent(poiId: id, action: action));
                if (action == TriggerAction.view) views.add(id);
              },
            ),
          ),
        ),
      );
      // Alternate real engine callbacks with fake UI frames until loading ends.
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
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(OfflineCampusMap), findsOneWidget);
      expect(find.text('Peta offline tidak dapat dimuat.'), findsNothing);
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);
      expect(find.text('© OpenMapTiles'), findsOneWidget);
      expect(find.text('Lihat'), findsNothing);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.text('Mode uji'), findsOneWidget);
      // FE 5db4dd4: top/right 12, 39 px controls, 7 px gaps,
      // centered above the 42 px session button. Demo label lives below the map.
      final mapRect = tester.getRect(find.byType(OfflineCampusMap));
      final controlIcons = [
        Icons.explore_outlined,
        Icons.my_location_rounded,
        Icons.layers_outlined,
      ];
      for (var index = 0; index < controlIcons.length; index++) {
        final button = find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox &&
              widget.width == 39 &&
              widget.height == 39 &&
              widget.child is Icon &&
              (widget.child! as Icon).icon == controlIcons[index],
        );
        final rect = tester.getRect(button);
        expect(rect.size, const Size(39, 39));
        expect(rect.center.dx, mapRect.right - 33);
        expect(rect.top, mapRect.top + 32 + index * 46);
        final icon = tester.widget<Icon>(
          find.byIcon(controlIcons[index]).first,
        );
        expect(icon.color, const Color(0xFF174F9E));
        expect(icon.size, 20);
      }
      expect(
        tester.getSize(find.byTooltip('Mulai Explore')),
        const Size(42, 42),
      );
      expect(
        tester.getRect(find.byTooltip('Mulai Explore')).top,
        mapRect.top + 170,
      );
      expect(mapRect.top, 94); // 54 px FE header + 40 px location status.
      final osmRect = tester.getRect(find.textContaining('OpenStreetMap'));
      final omtRect = tester.getRect(find.text('© OpenMapTiles'));
      expect(osmRect.top, omtRect.top); // Compact attribution stays one line.
      expect(osmRect.overlaps(omtRect), isFalse);
      final canvasRect = tester.getRect(find.byType(FlutterMap));
      expect(osmRect.bottom, lessThanOrEqualTo(canvasRect.top));
      expect(
        tester.getRect(find.text('Mode uji')).bottom,
        lessThanOrEqualTo(mapRect.top),
      );
      expect(find.text('Pusatkan'), findsNothing);
      expect(find.textContaining('engineering'), findsNothing);
      // Small phone: credits stay readable and controls keep the FE right inset.
      tester.view.physicalSize = const Size(320, 740);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.textContaining('OpenStreetMap')).top,
        tester.getRect(find.text('© OpenMapTiles')).top,
      );
      expect(tester.getRect(find.byTooltip('Mulai Explore')).right, 308);
      expect(
        tester.getSize(find.byType(CircleAvatar).first),
        const Size(32, 32),
      );
      tester.view.physicalSize = const Size(430, 900);
      await tester.pumpAndSettle();
      // Seluruh tab FE tetap tersedia; perpindahan tab tidak memulai sesi dummy.
      await tester.tap(find.text('Trail'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PRATINJAU'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Mulai Trail'), findsOneWidget);
      expect(session.current.isActive, isFalse);
      await tester.tap(find.byType(CircleAvatar).first);
      await tester.pumpAndSettle();
      expect(find.text('Profil Pengguna'), findsOneWidget);
      await tester.tap(find.text('Cari & Rute'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'labtek 6');
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Labtek VI'));
      // Real offline map loads in the search card too.
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
      await tester.ensureVisible(find.text('Tampilkan di peta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tampilkan di peta'));
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      expect(
        find.text('Lihat'),
        findsNothing,
      ); // Target stays visible on the map.
      final selectedMap = tester.widget<OfflineCampusMap>(
        find.byType(OfflineCampusMap),
      );
      expect(selectedMap.selectedPoiId, 'P02');
      final p02 = (await tester.runAsync(() => repository.poiById('P02')))!;
      expect(
        tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!
            .camera
            .center,
        LatLng(p02.position.lat, p02.position.lng),
      );
      expect(session.current.isActive, isFalse);
      await tester.tap(find.text('Jelajah'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(FlutterMap), const Offset(40, 0));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final center = LatLng(map.initialCenter.lat, map.initialCenter.lng);
      controller.move(center, 19); // Overzoom beyond archive maximum 16.
      await tester.pumpAndSettle();
      expect(controller.camera.zoom, 19);
      controller.move(center, 17);
      controller.rotate(45);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Arahkan peta ke utara'));
      await tester.pumpAndSettle();
      expect(controller.camera.rotation, 0);
      await tester.tap(find.byTooltip('Sembunyikan penanda POI'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        isEmpty,
      );
      await tester.tap(find.byTooltip('Tampilkan penanda POI'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
        10,
      );
      await tester.tap(find.byTooltip('Pusatkan lokasi saya'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Lokasi belum tersedia. Periksa izin'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mulai Explore'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pump();
      expect(session.current.mode, SessionMode.explore);
      final epoch = DateTime.utc(2026, 11, 14);
      void emit(int second, {double accuracy = 5}) => source.emit(
        LocationFix(
          position: poi.position,
          accuracyM: accuracy,
          timestamp: epoch.add(Duration(seconds: second)),
        ),
      );
      emit(0, accuracy: 30);
      emit(6, accuracy: 30);
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pump();
      expect(find.text('Lihat'), findsNothing);
      emit(7);
      emit(10);
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pump();
      expect(find.text('Lihat'), findsNothing); // <5 seconds dwell.
      await tester.tap(find.text('Cari & Rute'));
      await tester.pumpAndSettle();
      emit(13);
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      expect(find.text('Lihat'), findsOneWidget);
      expect(find.bySemanticsLabel('Posisi perangkat'), findsOneWidget);
      expect(find.byTooltip('Akhiri sesi'), findsOneWidget);
      final sheet = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_PoiSheet',
      );
      final nav = find.byType(AgamBottomNavigation);
      expect(tester.getRect(sheet).bottom, tester.getRect(nav).top);
      expect(tester.getRect(sheet).left, 0);
      expect(tester.getRect(sheet).right, 430);
      expect(
        find.textContaining('Konten yang belum diverifikasi'),
        findsNothing,
      );
      tester.view.physicalSize = const Size(320, 740);
      await tester.pumpAndSettle();
      expect(tester.getRect(sheet).bottom, tester.getRect(nav).top);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(430, 900);
      await tester.pumpAndSettle();
      controller.move(const LatLng(-6.889, 107.611), 18);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pusatkan lokasi saya'));
      await tester.pumpAndSettle();
      expect(
        controller.camera.center,
        LatLng(poi.position.lat, poi.position.lng),
      );
      await tester.runAsync(() async {
        final boundary =
            repaint.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final preview = File('tools/tiles/.cache/demo-labtek-v-widget.png');
        await preview.parent.create(recursive: true);
        await preview.writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
      // SIMULASI exit/re-entry: an inaccurate fix cannot dismiss the trigger;
      // a valid fix beyond hysteresis does, and cooldown still prevents spam.
      void leave(int second, {double accuracy = 5}) => source.emit(
        LocationFix(
          position: GeoPoint(poi.position.lat + 0.0003, poi.position.lng),
          accuracyM: accuracy,
          timestamp: epoch.add(Duration(seconds: second)),
        ),
      );
      leave(14, accuracy: 50);
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      expect(find.text('Lihat'), findsOneWidget);
      leave(15);
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      expect(find.text('Lihat'), findsNothing);
      emit(16);
      emit(19);
      emit(22);
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      expect(find.text('Lihat'), findsNothing);
      emit(613);
      emit(616);
      emit(619);
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      expect(find.text('Lihat'), findsOneWidget);
      await tester.tap(find.text('Pengaturan'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mode demo/trial'));
      await tester.tap(find.text('Mode demo/trial'));
      await tester.pumpAndSettle();
      expect(session.trialModeEnabled, isTrue);
      expect(session.current.mode, SessionMode.explore);
      await tester.tap(find.text('Jelajah'));
      await tester.pumpAndSettle();
      leave(620);
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      expect(find.text('Lihat'), findsNothing);
      emit(621);
      emit(624);
      emit(627);
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      expect(find.text('Lihat'), findsOneWidget); // Trial skips cooldown.
      await tester.tap(find.text('Pengaturan'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mode demo/trial'));
      await tester.tap(find.text('Mode demo/trial'));
      await tester.pumpAndSettle();
      expect(session.trialModeEnabled, isFalse);
      await tester.tap(find.text('Jelajah'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();
      expect(actions.last.action, TriggerAction.skip);
      expect(actions.last.poiId, 'P01');
      expect(find.text('Lihat'), findsNothing);
      expect(session.current.mode, SessionMode.explore);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Buka Labtek V',
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Lihat'), findsNothing);
      expect(session.current.mode, SessionMode.explore);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Buka Labtek V',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lihat'));
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PoiDetailScreen>(find.byType(PoiDetailScreen)).poi.id,
        'P01',
      );
      expect(actions.last.action, TriggerAction.view);
      expect(actions.last.poiId, 'P01');
      if (poi.metadata.approved && !poi.metadata.isPlaceholder) {
        // Dataset tim kini berisi media yang disetujui; tampilkan aset
        // repository yang sama, bukan memaksa konten final menjadi placeholder.
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    poi.media.photos.first,
          ),
          findsOneWidget,
        );
      } else {
        expect(find.textContaining('Informasi belum tersedia'), findsWidgets);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      views.add(
        'P02',
      ); // Separate notification "Lihat" channel must use its own ID.
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PoiDetailScreen>(find.byType(PoiDetailScreen)).poi.id,
        'P02',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Akhiri sesi'));
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      for (var i = 0; i < 10 && source.lastRequest!.sessionService; i++) {
        await tester.runAsync(() => pumpEventQueue(times: 5));
        await tester.pump();
      }
      expect(session.current.isActive, isFalse);
      expect(
        source.lastRequest!.sessionService,
        isFalse,
      ); // Map visible: foreground only.
      source.fail(LocationIssue.serviceDisabled);
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pump();
      expect(find.text('GPS perangkat mati. Aktifkan lokasi.'), findsOneWidget);
      expect(find.bySemanticsLabel('Posisi perangkat'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pump();
      await drain(session.dispose());
      await drain(location.dispose());
      await drain(views.close());
      await drain(repository.dispose());
      expect(source.activeSubscriptions, 0);
      debugDisableShadows = oldShadows;
      expect(tester.takeException(), isNull);
    },
  );
}
