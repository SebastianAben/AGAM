/// Implementasi asli [PermissionService] (PB02).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../../contracts/contracts.dart';

/// Akses platform yang dibutuhkan [DevicePermissionService]. Dipisah agar
/// logika pemetaan status dapat diuji tanpa plugin.
abstract interface class PermissionPlatform {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkLocationPermission();

  /// Meminta izin lokasi "saat aplikasi digunakan". Manifest AGAM tidak
  /// mendeklarasikan `ACCESS_BACKGROUND_LOCATION`, sehingga geolocator tidak
  /// pernah meminta izin "sepanjang waktu".
  Future<LocationPermission> requestLocationPermission();

  /// `null` jika tidak diketahui.
  Future<LocationAccuracyStatus?> locationAccuracy();

  Future<bool> notificationsEnabled();
  Future<bool> requestNotifications();
  Future<void> openAppSettings();
  Future<bool> isIgnoringBatteryOptimizations();
  Future<void> openBatteryOptimizationSettings();
}

class DevicePermissionService implements PermissionService {
  DevicePermissionService({PermissionPlatform? platform})
    : _platform = platform ?? PluginPermissionPlatform();

  final PermissionPlatform _platform;

  @override
  Future<LocationPermissionStatus> locationStatus() async {
    if (!await _platform.isLocationServiceEnabled()) {
      return LocationPermissionStatus.serviceDisabled;
    }
    final permission = await _platform.checkLocationPermission();
    return mapLocationStatus(permission, await _accuracyIfGranted(permission));
  }

  @override
  Future<LocationPermissionStatus> requestLocation() async {
    final current = await locationStatus();
    switch (current) {
      case LocationPermissionStatus.granted:
      case LocationPermissionStatus.permanentlyDenied:
      case LocationPermissionStatus.serviceDisabled:
        return current;
      case LocationPermissionStatus.denied:
      case LocationPermissionStatus.approximateOnly:
        // Untuk approximateOnly, Android 12+ menampilkan dialog peningkatan
        // ke lokasi akurat (PRD §19).
        final LocationPermission result;
        try {
          result = await _platform.requestLocationPermission();
        } on PermissionRequestInProgressException {
          return locationStatus();
        }
        return mapLocationStatus(result, await _accuracyIfGranted(result));
    }
  }

  @override
  Future<NotificationPermissionStatus> notificationStatus() async =>
      await _platform.notificationsEnabled()
      ? NotificationPermissionStatus.granted
      : NotificationPermissionStatus.denied;

  @override
  Future<NotificationPermissionStatus> requestNotification() async {
    if (await _platform.notificationsEnabled()) {
      return NotificationPermissionStatus.granted;
    }
    return await _platform.requestNotifications()
        ? NotificationPermissionStatus.granted
        : NotificationPermissionStatus.denied;
  }

  @override
  Future<void> openAppSettings() => _platform.openAppSettings();

  @override
  Future<bool> isBatteryOptimized() async =>
      !await _platform.isIgnoringBatteryOptimizations();

  @override
  Future<void> openBatteryOptimizationSettings() =>
      _platform.openBatteryOptimizationSettings();

  Future<LocationAccuracyStatus?> _accuracyIfGranted(
    LocationPermission permission,
  ) async => _isGranted(permission) ? _platform.locationAccuracy() : null;

  static bool _isGranted(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  /// Memetakan status plugin ke kontrak. Lokasi perkiraan (Android 12+)
  /// dilaporkan sebagai [LocationPermissionStatus.approximateOnly] karena
  /// trigger tidak dapat bekerja dengan akurasi ±1–3 km.
  @visibleForTesting
  static LocationPermissionStatus mapLocationStatus(
    LocationPermission permission,
    LocationAccuracyStatus? accuracy,
  ) {
    switch (permission) {
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.permanentlyDenied;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return accuracy == LocationAccuracyStatus.reduced
            ? LocationPermissionStatus.approximateOnly
            : LocationPermissionStatus.granted;
    }
  }
}

/// [PermissionPlatform] dengan geolocator, flutter_local_notifications, dan
/// channel `site.agam/battery` di `MainActivity.kt`.
class PluginPermissionPlatform implements PermissionPlatform {
  PluginPermissionPlatform({
    FlutterLocalNotificationsPlugin? notifications,
    this._battery = const MethodChannel('site.agam/battery'),
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notifications;
  final MethodChannel _battery;

  AndroidFlutterLocalNotificationsPlugin? get _android => _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkLocationPermission() =>
      Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestLocationPermission() =>
      Geolocator.requestPermission();

  @override
  Future<LocationAccuracyStatus?> locationAccuracy() async {
    try {
      return await Geolocator.getLocationAccuracy();
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<bool> notificationsEnabled() async =>
      await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> requestNotifications() async =>
      await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Jika status tidak dapat dibaca, aplikasi dianggap masih dibatasi agar
  /// onboarding tetap menampilkan panduan pengaturan baterai.
  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _battery.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _battery.invokeMethod<bool>('openBatteryOptimizationSettings');
    } on PlatformException {
      await openAppSettings();
    } on MissingPluginException {
      await openAppSettings();
    }
  }
}
