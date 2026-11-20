import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/logic/data/data.dart';
import 'package:agam/logic/search/poi_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled POIs and aliases resolve locally within one second', () async {
    var searches = 0;
    final repository = PoiRepositoryImpl(
      bundled: const BundledDataset(),
      cache: InMemoryDatasetCache(),
      remote: const UnavailableRemoteSource(),
    );
    final search = PoiSearchService(
      pois: repository,
      onSearch: () => searches++,
    );
    final all = await repository.watchPois().first;
    expect(all, hasLength(10));
    for (final (query, id) in [
      for (final poi in all) (poi.name, poi.id),
      ('labtek 5', 'P01'),
      (' Labtek   V ', 'P01'),
      ('lab 5', 'P01'),
      ('GKUT', 'P07'),
      ('Labtek Biru', 'P05'),
    ]) {
      final watch = Stopwatch()..start();
      final results = await search
          .search(query)
          .timeout(const Duration(seconds: 1));
      expect(results.first.id, id, reason: query);
      expect(watch.elapsed, lessThanOrEqualTo(const Duration(seconds: 1)));
    }
    expect(searches, 15);
    expect(await search.search('  '), isEmpty);
    expect(searches, 15);
    expect(await repository.watchFacilities().first, isEmpty);
    for (final category in FacilityCategory.values) {
      expect(
        await search.search(
          'toilet',
          includePois: false,
          facilityCategories: {category},
        ),
        isEmpty,
      );
    }
  });
  test(
    'search filters verified facilities and excludes placeholders',
    () async {
      final verified = ContentMetadata(
        sources: const ['SYNTHETIC fixture'],
        verifiedAt: DateTime(2026),
        owner: 'SYNTHETIC fixture',
        assetAttribution: const [],
        approved: true,
      );
      Facility fixture(
        String id,
        FacilityCategory category,
        ContentMetadata metadata,
      ) => Facility(
        id: id,
        name: 'Fasilitas sintetis',
        category: category,
        position: const GeoPoint(0, 0),
        description: '',
        metadata: metadata,
      );
      final search = PoiSearchService(
        pois: FakePoiRepository(
          pois: const [],
          facilities: [
            fixture('verified-toilet', FacilityCategory.toilet, verified),
            fixture('verified-kantin', FacilityCategory.kantin, verified),
            fixture(
              'placeholder-toilet',
              FacilityCategory.toilet,
              const ContentMetadata.placeholder(),
            ),
          ],
        ),
      );
      final results = await search.search(
        'FASILITAS',
        facilityCategories: {FacilityCategory.toilet},
        includePois: false,
      );
      expect(results.map((r) => r.id), ['verified-toilet']);
    },
  );
}
