import '../../contracts/contracts.dart';
import '../trail/account_visit_store.dart';
import 'repository_recommendation_service.dart';

/// Merangkai [RepositoryRecommendationService] untuk build produk dan demo
/// (F07, PRD §13).
///
/// [visits] dan [trail] wajib instance yang sama dengan yang dipakai trail,
/// agar rekomendasi melihat kunjungan yang sama. "Sudah dikunjungi" adalah
/// gabungan ID POI tersimpan per akun dan check-in trail; keduanya hanya
/// berisi ID POI di perangkat, tanpa posisi.
RecommendationService createRecommendationService({
  required PoiRepository pois,
  required FacilityService facilities,
  required AccountVisitStore visits,
  required String? Function() currentUid,
  required TrailService trail,
}) => RepositoryRecommendationService(
  pois: pois,
  facilities: facilities,
  visited: (uid) async => {
    ...await visits.read(uid),
    ...(await visits.readTrail(uid)).ids,
  },
  currentUid: currentUid,
  trail: trail,
);
