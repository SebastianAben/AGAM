import '../../contracts/contracts.dart';

/// Konfigurasi aset nyata PB04. Tidak mengubah coverage tile menjadi area layanan.
///
/// Produk memakai [campus], batas layanan yang ditetapkan 24 November 2026
/// (PRD §9.3/§22). [pendingServiceArea] tetap tersedia untuk keadaan tanpa
/// batas. [withServiceArea] hanya untuk geometri yang telah ditetapkan tim dan
/// memiliki sumber; constructor ini tidak memberikan persetujuan atas data
/// tersebut.
final class AgamMapConfig implements MapConfig {
  AgamMapConfig.pendingServiceArea()
    : campusArea = const CampusArea(polygon: []),
      serviceAreaSource = null;

  /// Bounds coverage engineering OSM way/177629384 v19 + margin 200 m
  /// (PRD §9.3).
  static const engineeringBounds = CampusArea(
    polygon: [
      GeoPoint(-6.89545535, 107.60635935),
      GeoPoint(-6.89545535, 107.61454265),
      GeoPoint(-6.88552795, 107.61454265),
      GeoPoint(-6.88552795, 107.60635935),
    ],
  );

  /// Batas layanan produk: Kampus Ganesha + ±200 m sesuai PRD §9.3, memakai
  /// [engineeringBounds]. Ditetapkan tim 24 November 2026; belum diverifikasi
  /// lapangan.
  factory AgamMapConfig.campus() => AgamMapConfig.withServiceArea(
    area: engineeringBounds,
    source:
        'PRODUK — batas layanan Kampus Ganesha + 200 m dari coverage '
        'engineering OSM way/177629384 v19 (PRD §9.3); ditetapkan '
        '24 November 2026, belum diverifikasi lapangan.',
  );

  AgamMapConfig.withServiceArea({
    required CampusArea area,
    required String source,
  }) : campusArea = CampusArea(polygon: List.unmodifiable(area.polygon)),
       serviceAreaSource = source.trim() {
    if (serviceAreaSource!.isEmpty ||
        campusArea.polygon.length < 3 ||
        campusArea.polygon.toSet().length < 3 ||
        campusArea.polygon.any((point) => !_validPoint(point))) {
      throw ArgumentError('Area layanan dan sumbernya wajib valid.');
    }
  }

  static const outsideAreaMessage = 'Anda berada di luar area Kampus Ganesha';
  static const pendingAreaMessage =
      'PLACEHOLDER — batas area layanan menunggu penetapan tim. '
      'Trigger dan navigasi belum tersedia.';

  /// Sumber keputusan/geometri layanan; null berarti TBD, bukan di luar kampus.
  final String? serviceAreaSource;
  bool get hasServiceArea => serviceAreaSource != null;

  @override
  final CampusArea campusArea;

  @override
  MapStyleSource get style => const MapStyleSource(
    tilesAssetPath: 'assets/map/ganesha.pmtiles',
    styleAssetPath: 'assets/map/agam-style.json',
    attribution: '© OpenStreetMap contributors (ODbL) · © OpenMapTiles',
  );

  /// Pusat kamera dari PRD §9.1 (P08 Oktagon, tengah area kampus).
  /// Bukan pintu masuk, lokasi pengguna, atau titik hasil survei baru.
  @override
  GeoPoint get initialCenter => const GeoPoint(-6.8890603, 107.6100470);

  /// Menolak aktivasi lokasi selama area belum ditetapkan atau titik invalid.
  /// Keanggotaan poligon mengikuti CampusArea pada kontrak v1.0.
  @override
  bool isInsideCampus(GeoPoint point) =>
      hasServiceArea && _validPoint(point) && campusArea.contains(point);

  static bool _validPoint(GeoPoint point) =>
      point.lat.isFinite &&
      point.lng.isFinite &&
      point.lat >= -90 &&
      point.lat <= 90 &&
      point.lng >= -180 &&
      point.lng <= 180;
}
