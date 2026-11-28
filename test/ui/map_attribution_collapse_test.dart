import 'package:agam/logic/map/agam_map_config.dart';
import 'package:agam/ui/widgets/offline_campus_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// OSMF Attribution Guidelines (PRD §14): the credit shows in full first,
// folds into an "(i)" button after five seconds or on a map touch, and the
// button brings it back.
final _osm = find.text('© OpenStreetMap contributors (ODbL)');
final _omt = find.text('© OpenMapTiles');
final _info = find.byTooltip('Tampilkan atribusi peta');

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      disableAnimations: reduceMotion,
    ),
    child: Scaffold(
      body: Align(alignment: Alignment.bottomLeft, child: child),
    ),
  ),
);

Future<void> _settleTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('tampil penuh, lalu menciut menjadi ⓘ setelah 5 detik', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    expect(_osm, findsOneWidget);
    expect(_omt, findsOneWidget);
    expect(_info, findsNothing);

    await tester.pump(const Duration(milliseconds: 4900));
    expect(_osm, findsOneWidget);
    expect(_info, findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await _settleTransition(tester);
    expect(_osm, findsNothing);
    expect(_omt, findsNothing);
    expect(_info, findsOneWidget);
    final target = tester.getSize(find.byType(IconButton));
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));

    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byType(IconButton)),
      matchesSemantics(
        tooltip: 'Tampilkan atribusi peta',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('ⓘ membuka lagi atribusi penuh, lalu menciut lagi', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    await tester.pump(MapAttribution.visibleFor);
    await _settleTransition(tester);
    expect(_info, findsOneWidget);

    await tester.tap(_info);
    await _settleTransition(tester);
    expect(_osm, findsOneWidget);
    expect(_omt, findsOneWidget);
    expect(_info, findsNothing);
    // Both credits keep their links.
    expect(find.widgetWithText(TextButton, '© OpenMapTiles'), findsOneWidget);

    await tester.pump(MapAttribution.visibleFor);
    await _settleTransition(tester);
    expect(_osm, findsNothing);
    expect(_info, findsOneWidget);
  });

  testWidgets('sentuhan pertama pada peta langsung menciutkan', (tester) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    await tester.pump(const Duration(seconds: 1));
    MapAttribution.notifyMapTouched();
    await _settleTransition(tester);
    expect(_osm, findsNothing);
    expect(_info, findsOneWidget);

    // Reopened: the next touch folds it again before the five seconds.
    await tester.tap(_info);
    await _settleTransition(tester);
    expect(_osm, findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    MapAttribution.notifyMapTouched();
    await _settleTransition(tester);
    expect(_info, findsOneWidget);
  });

  testWidgets('menciut dan membuka berjalan ±240 ms dengan ease-out', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    MapAttribution.notifyMapTouched();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    // Mid-way the credits fade out over the incoming button, no scale.
    final fading = tester.widget<FadeTransition>(
      find.ancestor(of: _osm, matching: find.byType(FadeTransition)).first,
    );
    expect(fading.opacity.value, inExclusiveRange(0, 1));
    expect(
      find.ancestor(of: _info, matching: find.byType(ScaleTransition)),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pump();
    expect(_osm, findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion: langsung berganti tanpa animasi', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const MapAttribution(), reduceMotion: true));
    expect(find.byType(AnimatedSize), findsNothing);
    await tester.pump(MapAttribution.visibleFor);
    await tester.pump();
    expect(_osm, findsNothing);
    expect(_info, findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);

    await tester.tap(_info);
    await tester.pump();
    expect(_osm, findsOneWidget);
    expect(_info, findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('hitungan berhenti selama tidak terlihat', (tester) async {
    Widget hosted(bool visible) =>
        _host(TickerMode(enabled: visible, child: const MapAttribution()));
    await tester.pumpWidget(hosted(false));
    await tester.pump(const Duration(seconds: 20));
    expect(_osm, findsOneWidget);

    // Shown at last: the full five seconds start now.
    await tester.pumpWidget(hosted(true));
    await tester.pump(const Duration(seconds: 4));
    expect(_osm, findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await _settleTransition(tester);
    expect(_info, findsOneWidget);
  });

  testWidgets('dilepas sebelum 5 detik tanpa timer tertinggal', (tester) async {
    await tester.pumpWidget(_host(const MapAttribution()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    // A touch after disposal reaches no listener.
    MapAttribution.notifyMapTouched();
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('menggeser peta offline menciutkan atribusinya', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineCampusMap(
            config: AgamMapConfig.campus(),
            pois: const [],
            onSelectPoi: (_) {},
          ),
        ),
      ),
    );
    // Tiles load on real async; fake time stands still meanwhile, so the
    // five-second countdown cannot fire before the drag.
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
    expect(_osm, findsOneWidget);

    await tester.drag(find.byType(OfflineCampusMap), const Offset(-80, 0));
    await _settleTransition(tester);
    expect(_osm, findsNothing);
    expect(_info, findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
