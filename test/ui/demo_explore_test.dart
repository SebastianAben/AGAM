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
        map: map,
        routing: fake.routing,
        navigation: fake.navigation,
        search: fake.search,
        recommendations: fake.recommendations,
        trail: fake.trail,
        facilities: fake.facilities,
      );
      final views = StreamController<String>.broadcast();
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
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mulai Explore'));
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
      emit(13);
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      expect(find.text('Lihat'), findsOneWidget);
      expect(find.bySemanticsLabel('Posisi perangkat'), findsOneWidget);
      expect(find.text('Akhiri sesi'), findsOneWidget);
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
      await tester.tap(find.text('Lihat'));
      await tester.runAsync(() => pumpEventQueue(times: 5));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PoiDetailScreen>(find.byType(PoiDetailScreen)).poi.id,
        'P01',
      );
      expect(find.textContaining('PLACEHOLDER'), findsWidgets);
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
      await tester.tap(find.text('Akhiri sesi'));
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
