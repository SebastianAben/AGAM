import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/contracts/fakes/fake_lb_services.dart';
import 'package:agam/logic/search/recommendation_bootstrap.dart';
import 'package:agam/logic/search/repository_facility_service.dart';
import 'package:agam/logic/trail/account_visit_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../trail/synthetic_trail.dart';

class _RecordingFacilityService implements FacilityService {
  _RecordingFacilityService(this._delegate);

  final FacilityService _delegate;
  final limits = <int>[];

  @override
  Future<List<FacilityDistance>> nearby({
    required GeoPoint from,
    FacilityCategory? category,
    int limit = 5,
  }) {
    limits.add(limit);
    return _delegate.nearby(from: from, category: category, limit: limit);
  }
}

List<Facility> _syntheticFacilities(int count) {
  final verified = ContentMetadata(
    sources: const ['SYNTHETIC fixture'],
    verifiedAt: DateTime(2026),
    owner: 'SYNTHETIC fixture',
    assetAttribution: const [],
    approved: true,
  );
  return List.generate(count, (i) {
    return Facility(
      id: 'synthetic-fac-$i',
      name: 'Fasilitas Sintetis $i',
      category: FacilityCategory.values[i % FacilityCategory.values.length],
      position: GeoPoint(-6.89, 107.608 + i * .0005),
      description: '',
      metadata: verified,
    );
  });
}

// Fixture sintetis: POI dan fasilitas sintetis berjajar ±55 m di satu garis,
// sehingga urutan jarak dapat dihitung tanpa rumus implementasi:
// dari synthetic-4: 3 dan 5 (1 langkah), 2 dan 6 (2 langkah), 1 dan 7 (3 langkah), dst.
// dari synthetic-fac-0: fac-0 (0 langkah), fac-1 (1), fac-2 (2), fac-3 (3).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'wired service: nearest unvisited without Trail, Trail order when active',
    () async {
      const uid = 'synthetic-A';
      String? current = uid;
      final repo = FakePoiRepository(pois: syntheticPois, facilities: []);
      final visits = AccountVisitStore();
      final session = SyntheticSession();
      final trail = FakeTrailService(
        session: session,
        order: syntheticPois.reversed.map((p) => p.id).toList(),
      );
      addTearDown(() async {
        await trail.dispose();
        await session.dispose();
      });
      // One stored visit and one Trail check-in, both in the same store the
      // Trail uses; the current POI is excluded as well.
      await visits.record(uid, 'synthetic-3');
      await visits.saveTrail(uid, {'synthetic-5'}, null);

      final service = createRecommendationService(
        pois: repo,
        facilities: RepositoryFacilityService(repo),
        visits: visits,
        currentUid: () => current,
        trail: trail,
      );
      Future<List<String>> ids() async => (await service.recommend(
        from: syntheticPois[4].position,
        afterPoiId: 'synthetic-4',
      )).poiIds;

      expect(await ids(), ['synthetic-2', 'synthetic-6', 'synthetic-1']);

      await trail.start();
      expect(await ids(), ['synthetic-9', 'synthetic-8', 'synthetic-7']);

      await trail.stop();
      // Another account sees none of synthetic-A's visits.
      current = 'synthetic-B';
      expect(await ids(), ['synthetic-3', 'synthetic-5', 'synthetic-2']);
    },
  );

  test('afterFacilityId excludes arrived facility while still returning up to 2 nearby facilities', () async {
    final facilities = _syntheticFacilities(4);
    final repo = FakePoiRepository(pois: syntheticPois, facilities: facilities);
    final recordingFacilities = _RecordingFacilityService(
      RepositoryFacilityService(repo),
    );
    final visits = AccountVisitStore();
    final session = SyntheticSession();
    final trail = FakeTrailService(session: session);
    addTearDown(() async {
      await trail.dispose();
      await session.dispose();
    });

    final service = createRecommendationService(
      pois: repo,
      facilities: recordingFacilities,
      visits: visits,
      currentUid: () => 'synthetic-A',
      trail: trail,
    );

    final origin = facilities[0].position;

    // Without afterFacilityId: identical behavior (limit 2, includes nearest).
    final defaultRec = await service.recommend(from: origin);
    expect(
      defaultRec.nearbyFacilities.map((item) => item.facility.id).toList(),
      ['synthetic-fac-0', 'synthetic-fac-1'],
    );
    expect(recordingFacilities.limits.last, 2);

    // Arrived at closest facility: excluded, next 2 facilities returned.
    final excludedFirst = await service.recommend(
      from: origin,
      afterFacilityId: 'synthetic-fac-0',
    );
    expect(
      excludedFirst.nearbyFacilities.map((item) => item.facility.id).toList(),
      ['synthetic-fac-1', 'synthetic-fac-2'],
    );
    expect(recordingFacilities.limits.last, 3);

    // Arrived at second closest facility: excluded, 1st and 3rd returned.
    final excludedSecond = await service.recommend(
      from: origin,
      afterFacilityId: 'synthetic-fac-1',
    );
    expect(
      excludedSecond.nearbyFacilities.map((item) => item.facility.id).toList(),
      ['synthetic-fac-0', 'synthetic-fac-2'],
    );

    // Arrived at facility outside top 2: still capped at 2 nearby facilities.
    final excludedFar = await service.recommend(
      from: origin,
      afterFacilityId: 'synthetic-fac-3',
    );
    expect(
      excludedFar.nearbyFacilities.map((item) => item.facility.id).toList(),
      ['synthetic-fac-0', 'synthetic-fac-1'],
    );
  });

  test(
    'afterFacilityId handles fewer than 3 total facilities gracefully',
    () async {
      final facilities = _syntheticFacilities(2);
      final repo = FakePoiRepository(
        pois: syntheticPois,
        facilities: facilities,
      );
      final visits = AccountVisitStore();
      final session = SyntheticSession();
      final trail = FakeTrailService(session: session);
      addTearDown(() async {
        await trail.dispose();
        await session.dispose();
      });

      final service = createRecommendationService(
        pois: repo,
        facilities: RepositoryFacilityService(repo),
        visits: visits,
        currentUid: () => 'synthetic-A',
        trail: trail,
      );

      final rec = await service.recommend(
        from: facilities[0].position,
        afterFacilityId: 'synthetic-fac-0',
      );
      expect(rec.nearbyFacilities.map((item) => item.facility.id).toList(), [
        'synthetic-fac-1',
      ]);
    },
  );
}
