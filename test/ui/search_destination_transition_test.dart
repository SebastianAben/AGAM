import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_data.dart';
import 'package:agam/ui/search_route_screen.dart';
import 'package:agam/ui/widgets/agam_arrival.dart';
import 'package:agam/ui/widgets/agam_components.dart';
import 'package:agam/ui/widgets/offline_campus_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS: fake services and fake POIs only.
void main() {
  testWidgets('switching destination keeps the card map and swaps the name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = AppServices.fake(tick: const Duration(milliseconds: 10));
    final first = fakePois[0];
    final second = fakePois[1];

    await tester.pumpWidget(
      MaterialApp(
        home: SearchRouteScreen(services: services, initialDestination: first),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final mapBefore = tester.state<OfflineCampusMapState>(
      find.byType(OfflineCampusMap),
    );
    final card = find.byType(AgamArrival);
    expect(
      find.descendant(of: card, matching: find.text(first.name)),
      findsOneWidget,
    );

    final row = find.widgetWithText(AgamListRow, second.name);
    await tester.ensureVisible(row);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 60));
    // The old name is still dissolving; the new one waits for the camera.
    expect(
      find.descendant(of: card, matching: find.text(first.name)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text(second.name)),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 600));

    // The same map instance travels; it is not rebuilt at the new place.
    expect(
      tester.state<OfflineCampusMapState>(find.byType(OfflineCampusMap)),
      same(mapBefore),
    );
    expect(
      find.descendant(of: card, matching: find.text(second.name)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text(first.name)),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('choosing a place further down scrolls back to the card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = AppServices.fake(tick: const Duration(milliseconds: 10));

    await tester.pumpWidget(
      MaterialApp(
        home: SearchRouteScreen(
          services: services,
          initialDestination: fakePois.first,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final list = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    double offset() => tester.state<ScrollableState>(list).position.pixels;

    final target = fakePois.firstWhere((poi) => poi.id == 'P08');
    final row = find.widgetWithText(AgamListRow, target.name);
    await tester.ensureVisible(row);
    await tester.pump(const Duration(milliseconds: 400));
    expect(offset(), greaterThan(0));

    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 200));
    expect(offset(), greaterThan(0), reason: 'scrolling, not jumping');
    await tester.pump(const Duration(milliseconds: 400));
    expect(offset(), 0);
    expect(find.byType(OfflineCampusMap).hitTestable(), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.descendant(
        of: find.byType(AgamArrival),
        matching: find.text(target.name),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  Widget host(String id, String text, {bool reduced = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: AgamArrival(
        id: id,
        arriveAfter: const Duration(milliseconds: 400),
        child: Text(text),
      ),
    ),
  );

  testWidgets('a new name waits for its arrival; a live update does not', (
    tester,
  ) async {
    await tester.pumpWidget(host('a', 'A · 120 m'));
    await tester.pumpWidget(host('a', 'A · 110 m'));
    expect(find.text('A · 110 m'), findsOneWidget);

    await tester.pumpWidget(host('b', 'B'));
    Opacity opacityOf(String text) => tester.widget<Opacity>(
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)),
    );

    // The old name dissolves over most of the wait instead of vanishing.
    await tester.pump(const Duration(milliseconds: 140));
    expect(find.text('B'), findsNothing, reason: 'still travelling');
    expect(opacityOf('A · 110 m').opacity, inExclusiveRange(.2, .9));
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.text('B'), findsNothing, reason: 'still travelling');
    expect(opacityOf('A · 110 m').opacity, lessThan(.05));

    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('B'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(opacityOf('B').opacity, 1);
  });

  testWidgets('reduced motion swaps the name without waiting for travel', (
    tester,
  ) async {
    await tester.pumpWidget(host('a', 'A', reduced: true));
    await tester.pumpWidget(host('b', 'B', reduced: true));
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.text('B'), findsOneWidget);
    expect(find.byType(ImageFiltered), findsNothing);
    await tester.pumpAndSettle();
  });
}
