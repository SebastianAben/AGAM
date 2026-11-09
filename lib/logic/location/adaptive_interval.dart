/// Interval GPS adaptif untuk efisiensi baterai (PRD §9.2 butir 9).
library;

import '../../contracts/contracts.dart';

/// Menentukan interval pembaruan lokasi berikutnya.
///
/// PRD: ±3 detik saat bergerak; diperlambat ke ±10 detik bila pengguna diam
/// atau berada >200 m dari POI terdekat.
///
/// Pengecualian engineering: interval **tidak** diperlambat selama pengguna
/// berada di dalam radius POI ditambah [approachBufferM]. Engine geofence
/// membatalkan dwell bila jeda antar-sampel lebih dari 10 detik, sehingga
/// interval lambat di dekat POI dapat menggagalkan trigger.
///
/// Nilai [approachBufferM], [stationaryRadiusM], dan [stationaryAfter]
/// **telah diterapkan, belum dikalibrasi** di lapangan.
///
/// Status diam dihitung dari satu titik jangkar di memori, bukan riwayat
/// lintasan (PRD A01).
class AdaptiveIntervalPolicy {
  AdaptiveIntervalPolicy({
    this.normal = const Duration(seconds: 3),
    this.slow = const Duration(seconds: 10),
    this.farFromPoiM = 200,
    this.approachBufferM = 30,
    this.stationaryRadiusM = 10,
    this.stationaryAfter = const Duration(seconds: 30),
  });

  final Duration normal;
  final Duration slow;

  /// Jarak ke titik tengah POI terdekat yang dianggap jauh (PRD §9.2).
  final double farFromPoiM;

  /// Zona di luar radius POI yang tetap memakai interval normal.
  final double approachBufferM;

  /// Perpindahan kurang dari ini dianggap diam.
  final double stationaryRadiusM;

  /// Lama tanpa perpindahan sebelum dianggap diam.
  final Duration stationaryAfter;

  GeoPoint? _anchor;
  DateTime? _anchorAt;

  /// Interval yang disarankan setelah [fix]. Pembacaan dengan akurasi lebih
  /// buruk dari 20 m tidak mengubah status diam.
  Duration evaluate(LocationFix fix, Iterable<Poi> pois) {
    if (fix.isAccurateForTrigger) _updateAnchor(fix);

    double? nearestCenter;
    var nearPoi = false;
    for (final poi in pois) {
      final d = fix.position.distanceTo(poi.position);
      if (nearestCenter == null || d < nearestCenter) nearestCenter = d;
      if (d <= poi.radiusM + approachBufferM) nearPoi = true;
    }
    if (nearestCenter == null || nearPoi) return normal;
    if (nearestCenter > farFromPoiM) return slow;
    if (isStationary(fix.timestamp)) return slow;
    return normal;
  }

  bool isStationary(DateTime now) =>
      _anchorAt != null && now.difference(_anchorAt!) >= stationaryAfter;

  /// Melupakan titik jangkar, mis. saat pembacaan lokasi berhenti.
  void reset() {
    _anchor = null;
    _anchorAt = null;
  }

  void _updateAnchor(LocationFix fix) {
    final anchor = _anchor;
    if (anchor == null ||
        fix.position.distanceTo(anchor) > stationaryRadiusM ||
        fix.timestamp.isBefore(_anchorAt!)) {
      _anchor = fix.position;
      _anchorAt = fix.timestamp;
    }
  }
}
