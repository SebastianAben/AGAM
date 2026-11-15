import '../../contracts/contracts.dart';

/// Konfigurasi aset nyata PB04. Tidak mengubah coverage tile menjadi area layanan.
///
/// Produk memakai [pendingServiceArea] selama PRD §22 belum diselesaikan;
/// [internalDemo] hanya untuk pengecualian demo eksplisit PRD §4/§9.3.
/// [withServiceArea] hanya untuk geometri yang telah ditetapkan tim dan memiliki
/// sumber; constructor ini tidak memberikan persetujuan atas data tersebut.
final class AgamMapConfig implements MapConfig {
  AgamMapConfig.pendingServiceArea()
    : campusArea = const CampusArea(polygon: []),
      serviceAreaSource = null;

  /// Area engineering khusus demo internal, dari coverage OSM PRD §9.3.
  /// Bukan penetapan batas layanan produk atau hasil survei lapangan.
  factory AgamMapConfig.internalDemo() => AgamMapConfig.withServiceArea(
    area: const CampusArea(
      polygon: [
        GeoPoint(-6.89545535, 107.60635935),
        GeoPoint(-6.89545535, 107.61454265),
        GeoPoint(-6.88552795, 107.61454265),
        GeoPoint(-6.88552795, 107.60635935),
      ],
    ),
    source:
        'DEMO INTERNAL — coverage engineering OSM way/177629384 v19; '
        'snapshot 4 November 2026 + margin 200 m (PRD §9.3).',
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

  /// Pusat kamera dari PRD §9.1: P08 normal, P01 Labtek V untuk demo internal.
  /// Bukan pintu masuk, lokasi pengguna, atau titik hasil survei baru.
  @override
  GeoPoint get initialCenter =>
      serviceAreaSource?.startsWith('DEMO INTERNAL') == true
      ? const GeoPoint(-6.8905811, 107.6097754)
      : const GeoPoint(-6.8890603, 107.6100470);

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
