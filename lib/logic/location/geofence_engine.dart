import '../../contracts/constants.dart';
import '../../contracts/models/content.dart';
import '../../contracts/models/geo.dart';
import '../../contracts/models/location.dart';

typedef GeofenceDistanceCalculator = double Function(
  GeoPoint from,
  GeoPoint to,
);

/// Kandidat trigger; mode, respons, dan efek samping ditentukan lapisan sesi.
class GeofenceEntry {
  const GeofenceEntry({required this.poiId, required this.triggeredAt});

  final String poiId;
  final DateTime triggeredAt;
}

/// Geofence sinkron di memori tanpa GPS, timer, penyimpanan, atau jaringan.
///
/// Margin 5 m dan jeda 10 detik adalah nilai engineering awal, belum
/// dikalibrasi di lapangan. Pemanggil mempertahankan instance untuk menjaga
/// cooldown dan menentukan [evaluate] `enabled` dari sesi serta area kampus.
class GeofenceEngine {
  GeofenceEngine({
    required Iterable<Poi> pois,
    this.hysteresisMarginM = 5,
    this.maxSampleGap = const Duration(seconds: 10),
    GeofenceDistanceCalculator? distanceCalculator,
  }) : _distance = distanceCalculator ?? _haversine {
    if (!hysteresisMarginM.isFinite || hysteresisMarginM < 0) {
      throw ArgumentError.value(hysteresisMarginM, 'hysteresisMarginM');
    }
    if (maxSampleGap <= Duration.zero) {
      throw ArgumentError.value(maxSampleGap, 'maxSampleGap');
    }
    final ids = <String>{};
    _pois = List.unmodifiable(
      pois.map((poi) {
        if (poi.id.trim().isEmpty || !ids.add(poi.id)) {
          throw ArgumentError('ID POI kosong atau duplikat');
        }
        if (!_validPosition(poi.position) ||
            !poi.radiusM.isFinite ||
            poi.radiusM <= 0) {
          throw ArgumentError('Posisi atau radius POI tidak valid');
        }
        return _PoiState(poi.id, poi.position, poi.radiusM);
      }),
    );
  }

  final double hysteresisMarginM;
  final Duration maxSampleGap;
  final GeofenceDistanceCalculator _distance;
  late final List<_PoiState> _pois;
  DateTime? _lastTimestamp;

  /// Timestamp sama/mundur diabaikan. Input buruk membatalkan dwell,
  /// tetapi tidak membuktikan keluar dan tidak menghapus cooldown.
  ///
  /// Nonaktif membersihkan dwell/pengunci kunjungan tanpa membaca posisi,
  /// menghitung jarak, atau memperbarui timestamp global. Cooldown bertahan.
  List<GeofenceEntry> evaluate(LocationFix fix, {required bool enabled}) {
    if (!enabled) {
      for (final poi in _pois) {
        poi.clearCandidate();
        poi.triggeredInside = false;
      }
      return const [];
    }
    final timestamp = fix.timestamp;
    if (_lastTimestamp != null && !timestamp.isAfter(_lastTimestamp!)) {
      return const [];
    }
    _lastTimestamp = timestamp;
    if (!_validPosition(fix.position) ||
        !fix.accuracyM.isFinite ||
        fix.accuracyM < 0 ||
        fix.accuracyM > kTriggerMaxAccuracyM) {
      for (final poi in _pois) {
        poi.clearCandidate();
      }
      return const [];
    }

    final entries = <GeofenceEntry>[];
    for (final poi in _pois) {
      final distance = _distance(fix.position, poi.position);
      if (!distance.isFinite || distance < 0) {
        poi.clearCandidate();
        continue;
      }
      if (poi.triggeredInside) {
        if (distance > poi.radiusM + hysteresisMarginM) {
          poi.triggeredInside = false;
          poi.clearCandidate();
        }
        continue;
      }
      if (distance > poi.radiusM) {
        poi.clearCandidate();
        continue;
      }
      if (poi.lastInsideSampleAt == null ||
          timestamp.difference(poi.lastInsideSampleAt!) > maxSampleGap) {
        poi.enteredAt = timestamp;
      }
      poi.lastInsideSampleAt = timestamp;
      if (timestamp.difference(poi.enteredAt!) < kTriggerDwell) continue;
      if (poi.lastTriggeredAt != null &&
          timestamp.difference(poi.lastTriggeredAt!) < kTriggerCooldown) {
        continue;
      }
      entries.add(GeofenceEntry(poiId: poi.id, triggeredAt: timestamp));
      poi.lastTriggeredAt = timestamp;
      poi.triggeredInside = true;
      poi.clearCandidate();
    }
    return entries;
  }

  static double _haversine(GeoPoint from, GeoPoint to) => from.distanceTo(to);

  static bool _validPosition(GeoPoint point) =>
      point.lat.isFinite &&
      point.lng.isFinite &&
      point.lat >= -90 &&
      point.lat <= 90 &&
      point.lng >= -180 &&
      point.lng <= 180;
}

/// Hanya konfigurasi POI, waktu, dan flag; tidak menyimpan posisi pengguna.
class _PoiState {
  _PoiState(this.id, this.position, this.radiusM);

  final String id;
  final GeoPoint position;
  final double radiusM;
  DateTime? enteredAt;
  DateTime? lastInsideSampleAt;
  bool triggeredInside = false;
  DateTime? lastTriggeredAt;

  void clearCandidate() {
    enteredAt = null;
    lastInsideSampleAt = null;
  }
}
