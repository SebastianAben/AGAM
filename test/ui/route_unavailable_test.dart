import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_data.dart';
import 'package:agam/ui/search_route_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors DeviceNavigationController without a campus graph: start() does
/// not throw, it publishes an error state.
class _UnavailableNavigation implements NavigationController {
  final _states = StreamController<NavigationState>.broadcast();
  NavigationState _current = const NavigationState.idle();

  @override
  NavigationState get current => _current;

  @override
  Stream<NavigationState> get state => _states.stream;

  @override
  Future<void> start(NavigationTarget target) async {
    _current = NavigationState(status: NavigationStatus.error, target: target);
    _states.add(_current);
  }

  @override
  Future<void> stop() async {
    _current = const NavigationState.idle();
    _states.add(_current);
  }
}

void main() {
  testWidgets('an unavailable route says so instead of announcing a preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = AppServices.fake(tick: const Duration(milliseconds: 10));
    final services = AppServices(
      permissions: fake.permissions,
      location: fake.location,
      pois: fake.pois,
      session: fake.session,
      audio: fake.audio,
      voice: fake.voice,
      settings: fake.settings,
      auth: fake.auth,
      activity: fake.activity,
      map: fake.map,
      routing: fake.routing,
      navigation: _UnavailableNavigation(),
      search: fake.search,
      recommendations: fake.recommendations,
      trail: fake.trail,
      facilities: fake.facilities,
    );
    // Keep a listener so the fake location starts walking and has a fix.
    final positions = services.location.positions.listen((_) {});
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(
      MaterialApp(
        home: SearchRouteScreen(
          services: services,
          initialDestination: fakePois.first,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final route = find.widgetWithText(FilledButton, 'Rute').first;
    await tester.ensureVisible(route);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(route);
    // The fake session awaits a stream cancel that resolves outside the
    // fake clock, so give the failure path a few real milliseconds.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Rute belum tersedia untuk tujuan ini.'), findsOneWidget);
    expect(find.textContaining('Rute pratinjau'), findsNothing);
    expect(services.session.current.isActive, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    // Cancel without awaiting: the returned future resolves outside the
    // fake clock and would block the test.
    unawaited(positions.cancel());
    await tester.pump(const Duration(seconds: 1));
  });
}
