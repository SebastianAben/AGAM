/// Sumber posisi perangkat (PB02).
///
/// Dipisah dari `DeviceLocationService` agar aturan kapan lokasi dibaca dapat
/// diuji tanpa GPS. Hanya [GeolocatorPositionSource] yang menyentuh plugin.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../contracts/contracts.dart';

/// Parameter satu langganan pembacaan lokasi.
@immutable
class LocationRequest {
  const LocationRequest({required this.interval, required this.sessionService});

  /// Interval pembaruan yang diminta ke Fused Location Provider.
  final Duration interval;

  /// `true` selama sesi: pembacaan memakai foreground service tipe
  /// `location` dengan notifikasi tetap sehingga tetap berjalan saat layar
  /// mati (PRD §6). `false` untuk mode peta biasa.
  final bool sessionService;

  @override
  bool operator ==(Object other) =>
      other is LocationRequest &&
      other.interval == interval &&
      other.sessionService == sessionService;

  @override
  int get hashCode => Object.hash(interval, sessionService);

  @override
  String toString() =>
      'LocationRequest(interval: $interval, sessionService: $sessionService)';
}

/// Penyebab pembacaan lokasi gagal.
enum LocationIssue { permissionDenied, serviceDisabled, other }

class LocationSourceException implements Exception {
  const LocationSourceException(this.issue, [this.message]);

  final LocationIssue issue;
  final String? message;

  @override
  String toString() => 'LocationSourceException($issue, $message)';
}

abstract interface class PositionSource {
  /// Aliran posisi sesuai [request]. Membatalkan langganan wajib
  /// menghentikan pembacaan dan foreground service. Error dipancarkan
  /// sebagai [LocationSourceException].
  Stream<LocationFix> watch(LocationRequest request);
}

/// Implementasi [PositionSource] dengan plugin `geolocator` (Fused Location
/// Provider; plugin memakai LocationManager bila Google Play Services tidak
/// tersedia).
///
/// Catatan perilaku plugin (geolocator_android 5.2.1, diperiksa dari source):
/// aliran posisi di-cache sampai langganan dibatalkan, dan membatalkan
/// langganan ikut menghentikan foreground service. Karena itu pergantian
/// parameter selalu berupa batal-lalu-langganan-baru.
class GeolocatorPositionSource implements PositionSource {
  const GeolocatorPositionSource();

  /// Teks notifikasi tetap selama sesi (PRD §6).
  static const sessionNotificationTitle = 'Sesi AGAM aktif';
  static const sessionNotificationText =
      'Lokasi hanya diproses di ponsel untuk mendeteksi gedung di sekitar '
      'Anda. Akhiri sesi dari aplikasi untuk berhenti.';

  @override
  Stream<LocationFix> watch(LocationRequest request) {
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      // Tanpa filter jarak: saat pengguna diam di dalam radius, dwell tetap
      // membutuhkan sampel berkala (PRD §9.2 butir 4).
      distanceFilter: 0,
      intervalDuration: request.interval,
      foregroundNotificationConfig: request.sessionService
          ? const ForegroundNotificationConfig(
              notificationTitle: sessionNotificationTitle,
              notificationText: sessionNotificationText,
              notificationChannelName: 'Sesi lokasi',
              notificationIcon: AndroidResource(
                name: 'ic_launcher',
                defType: 'mipmap',
              ),
              enableWakeLock: true,
              setOngoing: true,
            )
          : null,
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map(positionToFix)
        .transform(
          StreamTransformer<LocationFix, LocationFix>.fromHandlers(
            handleError: (error, stackTrace, sink) =>
                sink.addError(mapGeolocatorError(error), stackTrace),
          ),
        );
  }

  /// Mengubah [Position] plugin menjadi model kontrak. Hanya posisi,
  /// akurasi, dan waktu yang diambil.
  @visibleForTesting
  static LocationFix positionToFix(Position position) => LocationFix(
    position: GeoPoint(position.latitude, position.longitude),
    accuracyM: position.accuracy,
    timestamp: position.timestamp,
  );

  @visibleForTesting
  static LocationSourceException mapGeolocatorError(Object error) {
    if (error is LocationSourceException) return error;
    if (error is PermissionDeniedException) {
      return LocationSourceException(
        LocationIssue.permissionDenied,
        error.message,
      );
    }
    if (error is LocationServiceDisabledException) {
      return const LocationSourceException(LocationIssue.serviceDisabled);
    }
    return LocationSourceException(LocationIssue.other, '$error');
  }
}
