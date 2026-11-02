import 'geo.dart';

/// Area layanan AGAM: Kampus Ganesha + ±200 m (PRD §9.3).
class CampusArea {
  const CampusArea({required this.polygon});

  /// Titik-titik poligon searah atau berlawanan jarum jam, tanpa mengulang
  /// titik pertama di akhir.
  final List<GeoPoint> polygon;

  /// Apakah [point] berada di dalam area (ray casting).
  bool contains(GeoPoint point) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final crosses =
          (a.lat > point.lat) != (b.lat > point.lat) &&
          point.lng <
              (b.lng - a.lng) * (point.lat - a.lat) / (b.lat - a.lat) + a.lng;
      if (crosses) inside = !inside;
    }
    return inside;
  }
}

/// Sumber peta yang dibundel di APK.
class MapStyleSource {
  const MapStyleSource({
    required this.tilesAssetPath,
    required this.styleAssetPath,
    required this.attribution,
    this.isPlaceholder = false,
  });

  /// File `.pmtiles`.
  final String tilesAssetPath;

  final String styleAssetPath;

  /// Wajib ditampilkan di peta (lisensi ODbL).
  final String attribution;

  /// `true` selama tile belum dibuat; UI menampilkan latar polos.
  final bool isPlaceholder;
}
