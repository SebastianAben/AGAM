import 'content.dart';

enum SearchResultKind { poi, facility }

class SearchResult {
  const SearchResult({
    required this.kind,
    required this.id,
    required this.name,
    required this.score,
  });

  final SearchResultKind kind;
  final String id;
  final String name;

  /// Semakin besar semakin relevan. Hasil diurutkan menurun.
  final double score;
}

class FacilityDistance {
  const FacilityDistance({required this.facility, required this.distanceM});

  final Facility facility;
  final double distanceM;
}

class Recommendation {
  const Recommendation({required this.poiIds, required this.nearbyFacilities});

  /// 1–3 POI, urutan pertama paling direkomendasikan.
  final List<String> poiIds;

  final List<FacilityDistance> nearbyFacilities;
}

class TrailProgress {
  const TrailProgress({
    required this.order,
    required this.visited,
    required this.active,
    this.completedAt,
  });

  /// Urutan rekomendasi ID POI.
  final List<String> order;

  /// POI yang sudah check-in, termasuk yang dikunjungi di luar urutan.
  final Set<String> visited;

  /// Apakah pengguna sedang menjalankan trail.
  final bool active;

  /// Waktu 10/10 tercapai; lencana ditampilkan jika tidak `null`.
  final DateTime? completedAt;

  int get visitedCount => order.where(visited.contains).length;
  int get total => order.length;
  bool get isComplete => total > 0 && visitedCount == total;

  /// POI pertama dalam urutan yang belum dikunjungi.
  String? get nextPoiId {
    for (final id in order) {
      if (!visited.contains(id)) return id;
    }
    return null;
  }
}
