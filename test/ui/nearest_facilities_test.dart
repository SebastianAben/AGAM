import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/data/data.dart';
import 'package:agam/logic/search/repository_facility_service.dart';
import 'package:agam/ui/widgets/facility_labels.dart';
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
}
