import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../contracts/fakes/fake_la_services.dart';
import '../contracts/models/geo.dart';
import '../contracts/models/location.dart';
import '../contracts/services/la_services.dart';

/// Uses Android's foreground location permission and the device location feed.
/// Coordinates stay in memory and are never persisted or sent to a server.
class DevicePermissionService implements PermissionService {
  DevicePermissionService({PermissionService? optionalPermissions})
    : _optionalPermissions = optionalPermissions ?? FakePermissionService();

  final PermissionService _optionalPermissions;

  @override
  Future<LocationPermissionStatus> locationStatus() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionStatus.serviceDisabled;
    }

    final permission = await geo.Geolocator.checkPermission();
    return _toLocationStatus(permission);
  }

  @override
  Future<LocationPermissionStatus> requestLocation() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionStatus.serviceDisabled;
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    return _toLocationStatus(permission);
  }

  Future<LocationPermissionStatus> _toLocationStatus(
    geo.LocationPermission permission,
  ) async {
    if (permission == geo.LocationPermission.denied) {
      return LocationPermissionStatus.denied;
    }
    if (permission == geo.LocationPermission.deniedForever) {
      return LocationPermissionStatus.permanentlyDenied;
    }
    if (permission == geo.LocationPermission.unableToDetermine) {
      return LocationPermissionStatus.denied;
    }

    try {
      final accuracy = await geo.Geolocator.getLocationAccuracy();
      if (accuracy == geo.LocationAccuracyStatus.reduced) {
        return LocationPermissionStatus.approximateOnly;
      }
    } on Exception {
      return LocationPermissionStatus.denied;
    }
    return LocationPermissionStatus.granted;
  }

  @override
  Future<NotificationPermissionStatus> notificationStatus() =>
      _optionalPermissions.notificationStatus();

  @override
  Future<NotificationPermissionStatus> requestNotification() =>
      _optionalPermissions.requestNotification();

  @override
  Future<void> openAppSettings() async {
    await geo.Geolocator.openAppSettings();
  }

  @override
  Future<bool> isBatteryOptimized() =>
      _optionalPermissions.isBatteryOptimized();

  @override
  Future<void> openBatteryOptimizationSettings() =>
      _optionalPermissions.openBatteryOptimizationSettings();
}

/// Lazily listens to real device locations while at least one screen/session
/// is subscribed. Fixes are held only in memory.
class DeviceLocationService
    with WidgetsBindingObserver
    implements LocationService {
  DeviceLocationService() {
    WidgetsBinding.instance.addObserver(this);
    _controller = StreamController<LocationFix>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
  }

  late final StreamController<LocationFix> _controller;
  StreamSubscription<geo.Position>? _subscription;
  Future<void>? _starting;
  LocationFix? _lastFix;
  bool _isForeground = true;

  @override
  Stream<LocationFix> get positions => _controller.stream;

  @override
  LocationFix? get lastFix => _lastFix;

  void _start() {
    if (!_isForeground || _subscription != null || _starting != null) return;
    _starting = _startLocationUpdates();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      _start();
    } else {
      _stop();
    }
  }

  Future<void> _startLocationUpdates() async {
    try {
      if (!_isForeground || !await geo.Geolocator.isLocationServiceEnabled()) {
        return;
      }
      final permission = await geo.Geolocator.checkPermission();
      if (permission != geo.LocationPermission.whileInUse &&
          permission != geo.LocationPermission.always) {
        return;
      }
      if (!_isForeground || !_controller.hasListener) return;

      final subscription =
          geo.Geolocator.getPositionStream(
            locationSettings: const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen((position) {
            final fix = LocationFix(
              position: GeoPoint(position.latitude, position.longitude),
              accuracyM: position.accuracy,
              timestamp: position.timestamp,
            );
            _lastFix = fix;
            _controller.add(fix);
          }, onError: (_, _) {});

      if (_isForeground && _controller.hasListener) {
        _subscription = subscription;
      } else {
        await subscription.cancel();
      }
    } on Exception {
      // Permission or provider changes are reflected when the user retries.
    } finally {
      _starting = null;
    }
  }

  void _stop() {
    final subscription = _subscription;
    _subscription = null;
    unawaited(subscription?.cancel());
  }

  @visibleForTesting
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    await _controller.close();
  }
}
