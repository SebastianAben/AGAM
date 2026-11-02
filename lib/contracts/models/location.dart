import '../constants.dart';
import 'geo.dart';

/// Satu pembacaan posisi pengguna.
///
/// Hanya hidup di memori. Dilarang disimpan sebagai riwayat atau dikirim
/// ke server mana pun (PRD A01).
class LocationFix {
  const LocationFix({
    required this.position,
    required this.accuracyM,
    required this.timestamp,
  });

  final GeoPoint position;

  /// Radius ketidakpastian yang dilaporkan perangkat, dalam meter.
  final double accuracyM;

  final DateTime timestamp;

  /// Apakah pembacaan cukup akurat untuk dipakai sebagai trigger POI.
  bool get isAccurateForTrigger => accuracyM <= kTriggerMaxAccuracyM;
}

enum LocationPermissionStatus {
  /// Izin lokasi akurat "saat aplikasi digunakan" diberikan.
  granted,

  /// Pengguna hanya memberi lokasi perkiraan (Android 12+). Trigger tidak
  /// dapat bekerja; UI harus meminta lokasi akurat.
  approximateOnly,

  denied,

  /// Ditolak permanen; hanya bisa diubah dari pengaturan sistem.
  permanentlyDenied,

  /// Layanan lokasi perangkat dimatikan.
  serviceDisabled,
}

enum NotificationPermissionStatus { granted, denied }
