import '../../contracts/contracts.dart';

class RepositoryRecommendationService implements RecommendationService {
  const RepositoryRecommendationService({
    required this.pois,
    required this.facilities,
    required this.visited,
    required this.currentUid,
    required this.trail,
  });

  final PoiRepository pois;
  final FacilityService facilities;
  final Future<Set<String>> Function(String) visited;
  final String? Function() currentUid;
  final TrailService trail;

  @override
  Future<Recommendation> recommend({
    required GeoPoint from,
    String? afterPoiId,
    String? afterFacilityId,
  }) async {
    final uid = currentUid();
    final candidates = await pois.watchPois().first;
    final seen = uid == null ? const <String>{} : await visited(uid);
    final rawNearby = await facilities.nearby(
      from: from,
      limit: afterFacilityId == null ? 2 : 3,
    );
    final nearby = afterFacilityId == null
        ? rawNearby
        : rawNearby
              .where((item) => item.facility.id != afterFacilityId)
              .take(2)
              .toList();
    if (uid != currentUid()) {
      return const Recommendation(poiIds: [], nearbyFacilities: []);
    }
    final progress = trail.current;
    final eligible = {
      for (final poi in candidates)
        if (poi.id != afterPoiId &&
            !seen.contains(poi.id) &&
            !progress.visited.contains(poi.id))
          poi.id: poi,
    };
    final ids = progress.active
        ? progress.order.where(eligible.containsKey)
        : (eligible.values.toList()..sort((a, b) {
                final distance = from
                    .distanceTo(a.position)
                    .compareTo(from.distanceTo(b.position));
                return distance == 0 ? a.id.compareTo(b.id) : distance;
              }))
              .map((poi) => poi.id);
    return Recommendation(
      poiIds: ids.take(3).toList(),
      nearbyFacilities: nearby,
    );
  }
}
