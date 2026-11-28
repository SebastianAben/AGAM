import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/location/device_permission_service.dart';
import 'package:agam/logic/location/position_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _FakePlatform implements PermissionPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requestResult = LocationPermission.whileInUse;
  LocationAccuracyStatus? accuracy = LocationAccuracyStatus.precise;
  bool notifications = false;
  bool notificationRequestResult = true;
  bool ignoringBattery = false;
  int locationRequests = 0;
  int notificationRequests = 0;
  int batterySettingsOpened = 0;
  bool throwInProgress = false;

  /// Akurasi setelah dialog izin, mis. pengguna menaikkan ke lokasi akurat.
  LocationAccuracyStatus? accuracyAfterRequest;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkLocationPermission() async => permission;

  @override
  Future<LocationPermission> requestLocationPermission() async {
    locationRequests++;
    if (throwInProgress) {
      throw const PermissionRequestInProgressException('sedang berjalan');
    }
    if (accuracyAfterRequest != null) accuracy = accuracyAfterRequest;
    return permission = requestResult;
  }

  @override
  Future<LocationAccuracyStatus?> locationAccuracy() async => accuracy;

  @override
  Future<bool> notificationsEnabled() async => notifications;

  @override
  Future<bool> requestNotifications() async {
    notificationRequests++;
    return notifications = notificationRequestResult;
  }

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => ignoringBattery;

  @override
  Future<void> openBatteryOptimizationSettings() async =>
      batterySettingsOpened++;
}

void main() {
  late _FakePlatform platform;
  late DevicePermissionService service;

  setUp(() {
    platform = _FakePlatform();
    service = DevicePermissionService(platform: platform);
  });

  group('pemetaan status lokasi', () {
    const map = DevicePermissionService.mapLocationStatus;

    test('saat digunakan + akurat → granted', () {
      expect(
        map(LocationPermission.whileInUse, LocationAccuracyStatus.precise),
        LocationPermissionStatus.granted,
      );
    });

    test('lokasi perkiraan → approximateOnly', () {
      expect(
        map(LocationPermission.whileInUse, LocationAccuracyStatus.reduced),
        LocationPermissionStatus.approximateOnly,
      );
    });

    test('akurasi tidak diketahui dianggap granted', () {
      expect(
        map(LocationPermission.whileInUse, null),
        LocationPermissionStatus.granted,
      );
    });

    test('deniedForever → permanentlyDenied', () {
      expect(
        map(LocationPermission.deniedForever, null),
        LocationPermissionStatus.permanentlyDenied,
      );
    });

    test('denied dan unableToDetermine → denied', () {
      expect(
        map(LocationPermission.denied, null),
        LocationPermissionStatus.denied,
      );
      expect(
        map(LocationPermission.unableToDetermine, null),
        LocationPermissionStatus.denied,
      );
    });
  });

  group('izin lokasi', () {
    test('layanan lokasi mati dilaporkan tanpa meminta izin', () async {
      platform.serviceEnabled = false;
      expect(
        await service.requestLocation(),
        LocationPermissionStatus.serviceDisabled,
      );
      expect(platform.locationRequests, 0);
    });

    test('denied → meminta izin', () async {
      expect(await service.requestLocation(), LocationPermissionStatus.granted);
      expect(platform.locationRequests, 1);
    });

    test('sudah granted tidak meminta ulang', () async {
      platform.permission = LocationPermission.whileInUse;
      expect(await service.requestLocation(), LocationPermissionStatus.granted);
      expect(platform.locationRequests, 0);
    });

    test('approximateOnly meminta ulang untuk lokasi akurat', () async {
      platform
        ..permission = LocationPermission.whileInUse
        ..accuracy = LocationAccuracyStatus.reduced;
      expect(
        await service.locationStatus(),
        LocationPermissionStatus.approximateOnly,
      );
      platform.accuracyAfterRequest = LocationAccuracyStatus.precise;
      expect(await service.requestLocation(), LocationPermissionStatus.granted);
      expect(platform.locationRequests, 1);
    });

    test('permanentlyDenied tidak meminta ulang', () async {
      platform.permission = LocationPermission.deniedForever;
      expect(
        await service.requestLocation(),
        LocationPermissionStatus.permanentlyDenied,
      );
      expect(platform.locationRequests, 0);
    });

    test(
      'permintaan yang sedang berjalan mengembalikan status terkini',
      () async {
        platform.throwInProgress = true;
        expect(
          await service.requestLocation(),
          LocationPermissionStatus.denied,
        );
      },
    );
  });

  group('notifikasi dan baterai', () {
    test('notifikasi diminta hanya jika belum aktif', () async {
      expect(
        await service.notificationStatus(),
        NotificationPermissionStatus.denied,
      );
      expect(
        await service.requestNotification(),
        NotificationPermissionStatus.granted,
      );
      expect(
        await service.requestNotification(),
        NotificationPermissionStatus.granted,
      );
      expect(platform.notificationRequests, 1);
    });

    test('notifikasi ditolak', () async {
      platform.notificationRequestResult = false;
      expect(
        await service.requestNotification(),
        NotificationPermissionStatus.denied,
      );
    });

    test('status optimasi baterai', () async {
      expect(await service.isBatteryOptimized(), isTrue);
      platform.ignoringBattery = true;
      expect(await service.isBatteryOptimized(), isFalse);
      await service.openBatteryOptimizationSettings();
      expect(platform.batterySettingsOpened, 1);
    });
  });

  group('pemetaan error geolocator', () {
    const map = GeolocatorPositionSource.mapGeolocatorError;

    test('izin ditolak', () {
      expect(
        map(const PermissionDeniedException('x')).issue,
        LocationIssue.permissionDenied,
      );
    });

    test('layanan lokasi mati', () {
      expect(
        map(const LocationServiceDisabledException()).issue,
        LocationIssue.serviceDisabled,
      );
    });

    test('lainnya', () {
      expect(map(StateError('x')).issue, LocationIssue.other);
    });
  });
}
