import 'package:agam/contracts/contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pencarian palsu menempatkan Labtek V teratas untuk semua alias',
    () async {
      final services = AppServices.fake();
      for (final query in ['labtek 5', 'Labtek V', 'lab 5']) {
        final results = await services.search.search(query);
        expect(results.first.id, 'P01', reason: query);
      }
    },
  );

  test('simulasi berjalan memicu POI dan mencatat check-in trail', () async {
    final services = AppServices.fake(tick: const Duration(milliseconds: 1));

    final firstTrigger = services.session.triggers.first;
    await services.session.start(SessionMode.trail);
    await services.trail.start();

    final event = await firstTrigger.timeout(const Duration(seconds: 5));
    expect(event.poiId, 'P06');
    expect(event.response, TriggerResponse.full);

    await pumpEventQueue();
    expect(services.trail.current.visited, contains('P06'));

    await services.session.end();
    expect(services.session.current.isActive, isFalse);
  });

  test('mode Navigasi memberi respons trigger ringkas', () async {
    final services = AppServices.fake(tick: const Duration(milliseconds: 1));

    final firstTrigger = services.session.triggers.first;
    await services.session.start(SessionMode.navigation);

    final event = await firstTrigger.timeout(const Duration(seconds: 5));
    expect(event.response, TriggerResponse.brief);
    await services.session.end();
  });

  test('navigasi palsu menyatakan tiba di radius 15 m', () async {
    final services = AppServices.fake(tick: const Duration(milliseconds: 1));
    final labtek5 = (await services.pois.poiById('P01'))!;

    final arrived = services.navigation.state.firstWhere(
      (s) => s.status == NavigationStatus.arrived,
    );
    await services.navigation.start(NavigationTarget.poi(labtek5));

    final state = await arrived.timeout(const Duration(seconds: 5));
    expect(state.remainingDistanceM, lessThanOrEqualTo(kArrivalDistanceM));
    expect(state.target!.isPlaceholderPoint, isTrue);
  });

  test('peta palsu mencakup seluruh POI', () async {
    final services = AppServices.fake();
    final pois = await services.pois.watchPois().first;
    expect(pois, hasLength(10));
    for (final poi in pois) {
      expect(services.map.isInsideCampus(poi.position), isTrue, reason: poi.id);
    }
    expect(services.map.style.isPlaceholder, isTrue);
  });
}
