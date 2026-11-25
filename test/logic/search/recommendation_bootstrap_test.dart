import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/contracts/fakes/fake_lb_services.dart';
import 'package:agam/logic/search/recommendation_bootstrap.dart';
import 'package:agam/logic/search/repository_facility_service.dart';
import 'package:agam/logic/trail/account_visit_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../trail/synthetic_trail.dart';

// Fixture sintetis: POI sintetis berjajar ±55 m di satu garis, sehingga
// urutan jarak dari synthetic-4 dapat dihitung tanpa rumus implementasi:
// 3 dan 5 (1 langkah), 2 dan 6 (2 langkah), 1 dan 7 (3 langkah), dst.
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
}
