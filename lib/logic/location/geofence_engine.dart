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
    this.entranceRadiusM = 10,
    this.hysteresisMarginM = 5,
    this.maxSampleGap = const Duration(seconds: 10),
    GeofenceDistanceCalculator? distanceCalculator,
  }) : _distance = distanceCalculator ?? _haversine {
    if (!entranceRadiusM.isFinite || entranceRadiusM < 0) {
      throw ArgumentError.value(entranceRadiusM, 'entranceRadiusM');
    }
    if (!hysteresisMarginM.isFinite || hysteresisMarginM < 0) {
      throw ArgumentError.value(hysteresisMarginM, 'hysteresisMarginM');
    }
    if (maxSampleGap <= Duration.zero) {
      throw ArgumentError.value(maxSampleGap, 'maxSampleGap');
    }
    _pois = _buildStates(pois);
  }

  /// Area kontak di sekitar koordinat trigger; radius pendekatan POI tetap.
  static const contactRadiusM = 5.0;

  /// Radius zona pendekatan di sekitar setiap titik akses (`poi.entrances`).
  final double entranceRadiusM;
  final double hysteresisMarginM;
  final Duration maxSampleGap;
  final GeofenceDistanceCalculator _distance;
  late List<_PoiState> _pois;
  DateTime? _lastTimestamp;
  bool _trialMode = false;

  /// Uji developer: reset cooldown saat diaktifkan dan lewati jedanya selama
  /// aktif. Pengunci kunjungan tetap: harus keluar sebelum trigger berikutnya.
  void setTrialMode(bool enabled) {
    if (_trialMode == enabled) return;
    _trialMode = enabled;
    if (enabled) {
      for (final poi in _pois) {
        poi.lastTriggeredAt = null;
      }
    }
  }

  /// Snapshot ID kunjungan yang masih terkunci di dalam histeresis.
  Set<String> get activePoiIds => {
    for (final poi in _pois)
      if (poi.triggeredInside) poi.id,
  };

  /// Timestamp sama/mundur diabaikan. Input buruk membatalkan dwell,
  /// tetapi tidak membuktikan keluar dan tidak menghapus cooldown.
  ///
  /// Nonaktif membersihkan dwell/pengunci kunjungan tanpa membaca posisi,
  /// menghitung jarak, atau memperbarui timestamp global. Cooldown bertahan.
  List<GeofenceEntry> evaluate(LocationFix fix, {required bool enabled}) {
    if (!enabled) {
      suspend();
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
      interruptDwell();
      return const [];
    }

    final entries = <GeofenceEntry>[];
    final entranceExitRadiusM = entranceRadiusM + hysteresisMarginM;
    for (final poi in _pois) {
      final centerDistance = _distance(fix.position, poi.position);
      if (!centerDistance.isFinite || centerDistance < 0) {
        poi.clearCandidate();
        continue;
      }
      var invalidEntranceDistance = false;
      var insideAnyEntrance = false;
      var outsideAllEntrancesHysteresis = true;
      for (final entrance in poi.entrances) {
        final d = _distance(fix.position, entrance);
        if (!d.isFinite || d < 0) {
          invalidEntranceDistance = true;
          break;
        }
        if (d <= entranceRadiusM) insideAnyEntrance = true;
        if (d <= entranceExitRadiusM) outsideAllEntrancesHysteresis = false;
      }
      if (invalidEntranceDistance) {
        poi.clearCandidate();
        continue;
      }
      if (poi.triggeredInside) {
        final outsideCenterHysteresis =
            centerDistance > poi.radiusM + contactRadiusM + hysteresisMarginM;
        if (outsideCenterHysteresis && outsideAllEntrancesHysteresis) {
          poi.triggeredInside = false;
          poi.clearCandidate();
        }
        continue;
      }
      final insideCenter = centerDistance <= poi.radiusM + contactRadiusM;
      if (!insideCenter && !insideAnyEntrance) {
        poi.clearCandidate();
        continue;
      }
      if (poi.lastInsideSampleAt == null ||
          timestamp.difference(poi.lastInsideSampleAt!) > maxSampleGap) {
        poi.enteredAt = timestamp;
      }
      poi.lastInsideSampleAt = timestamp;
      if (timestamp.difference(poi.enteredAt!) < kTriggerDwell) continue;
      if (!_trialMode &&
          poi.lastTriggeredAt != null &&
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

  /// Sama dengan [evaluate] dengan `enabled: false`, tanpa membutuhkan
  /// pembacaan lokasi: dwell dan pengunci kunjungan dibersihkan, cooldown
  /// dipertahankan. Dipakai saat sesi berakhir atau pengguna di luar area.
  void suspend() {
    for (final poi in _pois) {
      poi.clearCandidate();
      poi.triggeredInside = false;
    }
  }

  /// Kehilangan GPS membatalkan kontinuitas dwell, tetapi bukan bukti keluar.
  /// Pengunci kunjungan dan cooldown tetap bertahan tanpa posisi sintetis.
  void interruptDwell() {
    for (final poi in _pois) {
      poi.clearCandidate();
    }
  }

  /// Mengganti snapshot POI, mis. setelah data diperbarui dari Firestore.
  ///
  /// Cooldown dipertahankan per ID agar POI yang sama tidak terpicu ulang
  /// karena dataset diperbarui. Dwell dan pengunci kunjungan hanya
  /// dipertahankan bila posisi, radius, dan posisi titik akses POI tidak
  /// berubah. POI yang dihapus ikut dilupakan. Validasi sama dengan
  /// konstruktor; jika gagal, snapshot lama tetap dipakai.
  void updatePois(Iterable<Poi> pois) {
    final previous = {for (final poi in _pois) poi.id: poi};
    final next = _buildStates(pois);
    for (final poi in next) {
      final old = previous[poi.id];
      if (old == null) continue;
      poi.lastTriggeredAt = old.lastTriggeredAt;
      if (old.position == poi.position &&
          old.radiusM == poi.radiusM &&
          _sameEntrances(old.entrances, poi.entrances)) {
        poi.enteredAt = old.enteredAt;
        poi.lastInsideSampleAt = old.lastInsideSampleAt;
        poi.triggeredInside = old.triggeredInside;
      }
    }
    _pois = next;
  }

  static List<_PoiState> _buildStates(Iterable<Poi> pois) {
    final ids = <String>{};
    return List.unmodifiable(
      pois.map((poi) {
        if (poi.id.trim().isEmpty || !ids.add(poi.id)) {
          throw ArgumentError('ID POI kosong atau duplikat');
        }
        if (!_validPosition(poi.position) ||
            !poi.radiusM.isFinite ||
            poi.radiusM <= 0) {
          throw ArgumentError('Posisi atau radius POI tidak valid');
        }
        final entrances = List<GeoPoint>.unmodifiable(
          poi.entrances.map((entrance) {
            if (!_validPosition(entrance.position)) {
              throw ArgumentError('Posisi titik akses POI tidak valid');
            }
            return entrance.position;
          }),
        );
        return _PoiState(poi.id, poi.position, poi.radiusM, entrances);
      }),
    );
  }

  static bool _sameEntrances(List<GeoPoint> a, List<GeoPoint> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
  _PoiState(this.id, this.position, this.radiusM, this.entrances);

  final String id;
  final GeoPoint position;
  final double radiusM;
  final List<GeoPoint> entrances;
  DateTime? enteredAt;
  DateTime? lastInsideSampleAt;
  bool triggeredInside = false;
  DateTime? lastTriggeredAt;

  void clearCandidate() {
    enteredAt = null;
    lastInsideSampleAt = null;
  }
}
