// SINTETIS — helper test track LA. Koordinat di sekitar (0, 0), bukan data
// kampus. Jarak acuan dihitung terpisah: 1e-4 derajat lintang ≈ 11,1195 m
// (R = 6.371.000 m; 6371000 × π / 180 × 1e-4), bukan dari implementasi.
import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/location/position_source.dart';

final syntheticEpoch = DateTime.utc(2026, 1, 1);

/// Meter → derajat lintang di khatulistiwa (≈111.194,9 m per derajat).
double metersToLat(double meters) => meters / 111194.93;

Poi syntheticPoi({
  String id = 'synthetic-a',
  double radius = 15,
  GeoPoint position = const GeoPoint(0, 0),
  PoiMedia media = const PoiMedia(),
  String name = 'SINTETIS',
}) => Poi(
  id: id,
  name: name,
  aliases: const [],
  category: PoiCategory.lecture,
  position: position,
  radiusM: radius,
  entrances: const [],
  description: 'SINTETIS',
  function: 'SINTETIS',
  facilities: const [],
  trivia: 'SINTETIS',
  media: media,
  metadata: const ContentMetadata.placeholder(),
);

/// Pembacaan pada [metersNorth] di utara (0, 0), [seconds] setelah epoch.
LocationFix syntheticFix(
  double seconds, {
  double metersNorth = 0,
  double accuracy = 5,
}) => LocationFix(
  position: GeoPoint(metersToLat(metersNorth), 0),
  accuracyM: accuracy,
  timestamp: syntheticEpoch.add(
    Duration(milliseconds: (seconds * 1000).round()),
  ),
);

/// [PositionSource] palsu yang mencatat setiap permintaan langganan.
class RecordingPositionSource implements PositionSource {
  final requests = <LocationRequest>[];
  StreamController<LocationFix>? _controller;
  int activeSubscriptions = 0;

  @override
  Stream<LocationFix> watch(LocationRequest request) {
    requests.add(request);
    final controller = StreamController<LocationFix>(
      onListen: () => activeSubscriptions++,
      onCancel: () => activeSubscriptions--,
    );
    _controller = controller;
    return controller.stream;
  }

  LocationRequest? get lastRequest => requests.isEmpty ? null : requests.last;

  void emit(LocationFix fix) => _controller!.add(fix);

  void fail(LocationIssue issue) =>
      _controller!.addError(LocationSourceException(issue));
}
