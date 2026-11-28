import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/data/data.dart';
import 'package:agam/logic/search/repository_facility_service.dart';
import 'package:agam/ui/widgets/agam_poi_panel.dart';
import 'package:agam/ui/widgets/facility_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS — not campus data.
FacilityDistance _at(String id, FacilityCategory category, double m) =>
    FacilityDistance(
      facility: Facility(
        id: id,
        name: id,
        category: category,
        position: const GeoPoint(0, 0),
        description: '',
        metadata: const ContentMetadata.placeholder(),
      ),
      distanceM: m,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps the nearest facility of each category in distance order', () {
    final picked = nearestPerCategory([
      _at('toilet-a', FacilityCategory.toilet, 5),
      _at('toilet-b', FacilityCategory.toilet, 20),
      _at('kantin-a', FacilityCategory.kantin, 30),
      _at('toilet-c', FacilityCategory.toilet, 40),
      _at('musala-a', FacilityCategory.musala, 50),
      _at('atm-a', FacilityCategory.atm, 60),
      _at('perpus-a', FacilityCategory.perpustakaan, 70),
    ]);
    expect(picked.map((f) => f.id), [
      'toilet-a',
      'kantin-a',
      'musala-a',
      'atm-a',
    ]);
  });

  test('returns fewer when there are fewer categories', () {
    expect(nearestPerCategory(const []), isEmpty);
    expect(
      nearestPerCategory([
        _at('toilet-a', FacilityCategory.toilet, 5),
        _at('toilet-b', FacilityCategory.toilet, 6),
      ]).map((f) => f.id),
      ['toilet-a'],
    );
  });

  test('around TVST the bundled dataset gives four different kinds', () async {
    final repository = PoiRepositoryImpl(
      bundled: const BundledDataset(),
      cache: InMemoryDatasetCache(),
      remote: const UnavailableRemoteSource(),
    );
    final pois = await repository.watchPois().first;
    final tvst = pois.singleWhere((poi) => poi.id == 'P09');
    final nearby = await RepositoryFacilityService(repository)
        .nearby(from: tvst.position, limit: 1000);

    final picked = nearestPerCategory(nearby);
    expect(picked, hasLength(4));
    expect(picked.map((f) => f.category).toSet(), hasLength(4));
    expect(picked.first.name, 'Toilet TVST');
  });

  testWidgets(
    'the panel edge fades only while more sits below, keeping the scroll',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      Widget body(int rows) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: AgamScrollEdgeFade(
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    // SINTETIS rows standing in for facility chips.
                    for (var i = 0; i < rows; i++)
                      SizedBox(height: 40, child: Text('SINTETIS $i')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      double strength() => tester
          .widget<TweenAnimationBuilder<double>>(
            find.descendant(
              of: find.byType(AgamScrollEdgeFade),
              matching: find.byType(TweenAnimationBuilder<double>),
            ),
          )
          .tween
          .end!;

      await tester.pumpWidget(body(20));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AgamScrollEdgeFade),
          matching: find.byType(ShaderMask),
        ),
        findsOneWidget,
      );
      expect(strength(), 1); // Rows continue below the edge.

      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(strength(), 0); // The last row is never dimmed.
      // The mask stays in the tree, so the scroll view keeps its offset.
      expect(scroll.offset, scroll.position.maxScrollExtent);

      await tester.pumpWidget(body(3)); // Everything fits: no fade.
      await tester.pumpAndSettle();
      expect(strength(), 0);
      expect(tester.takeException(), isNull);
    },
  );
}
