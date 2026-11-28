import '../../contracts/contracts.dart';

class RepositoryFacilityService implements FacilityService {
  const RepositoryFacilityService(this._pois);

  final PoiRepository _pois;

  @override
  Future<List<FacilityDistance>> nearby({
    required GeoPoint from,
    FacilityCategory? category,
    int limit = 5,
  }) async {
    if (limit <= 0) return const [];
    final facilities = await _pois.watchFacilities().first;
    final distances = [
      for (final facility in facilities)
        if (facility.metadata.approved &&
            !facility.metadata.isPlaceholder &&
            (category == null || facility.category == category))
          FacilityDistance(
            facility: facility,
            distanceM: from.distanceTo(facility.position),
          ),
    ]..sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return distances.take(limit).toList();
  }
}

/// PB14 has no active recommendation flow yet.
class UnavailableRecommendationService implements RecommendationService {
  const UnavailableRecommendationService();

  @override
  Future<Recommendation> recommend({
    required GeoPoint from,
    String? afterPoiId,
    String? afterFacilityId,
  }) async => const Recommendation(poiIds: [], nearbyFacilities: []);
}
