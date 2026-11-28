import 'dart:async';

import 'package:agam/logic/location/position_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

// SINTETIS: menguji adapter plugin, bukan GPS/perangkat atau acceptance fisik.
void main() {
  const request = LocationRequest(
    interval: Duration(seconds: 3),
    sessionService: true,
  );
  final position = Position(
    latitude: 0,
    longitude: 0,
    timestamp: DateTime.utc(2026),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  test('FLP tetap sumber utama dan tidak meminta fix historis', () async {
    final requests = <AndroidSettings>[];
    final source = GeolocatorPositionSource(
      positionStream: (settings) {
        requests.add(settings);
        return Stream.value(position);
      },
    );
    final fixes = await source.watch(request).toList();
    expect(fixes.single.accuracyM, 5);
    expect(requests.single.forceLocationManager, isFalse);
    expect(requests.single.maxUpdateAge, Duration.zero);
  });

  test('Google Accuracy ditolak dengan GPS aktif memakai fallback lokal; '
      'parameter foreground/dwell dipertahankan antar-langganan', () async {
    final requests = <AndroidSettings>[];
    final source = GeolocatorPositionSource(
      serviceEnabled: () async => true,
      positionStream: (settings) {
        requests.add(settings);
        return settings.forceLocationManager
            ? Stream.value(position)
            : Stream.error(const LocationServiceDisabledException());
      },
    );
    expect(await source.watch(request).toList(), hasLength(1));
    expect(requests.map((r) => r.forceLocationManager), [false, true]);
    expect(await source.watch(request).toList(), hasLength(1));
    expect(requests.map((r) => r.forceLocationManager), [false, true, true]);
    for (final settings in requests) {
      expect(settings.accuracy, LocationAccuracy.high);
      expect(settings.distanceFilter, 0);
      expect(settings.intervalDuration, const Duration(seconds: 3));
      expect(settings.foregroundNotificationConfig?.enableWakeLock, isTrue);
    }
  });

  test('GPS benar-benar mati tidak memaksa fallback', () async {
    var calls = 0;
    final source = GeolocatorPositionSource(
      serviceEnabled: () async => false,
      positionStream: (_) {
        calls++;
        return Stream.error(const LocationServiceDisabledException());
      },
    );
    await expectLater(
      source.watch(request),
      emitsError(
        isA<LocationSourceException>().having(
          (e) => e.issue,
          'issue',
          LocationIssue.serviceDisabled,
        ),
      ),
    );
    expect(calls, 1);
  });

  test('izin ditolak tidak dicoba ulang lewat provider lain', () async {
    var calls = 0;
    final source = GeolocatorPositionSource(
      positionStream: (_) {
        calls++;
        return Stream.error(const PermissionDeniedException('SINTETIS'));
      },
    );
    await expectLater(
      source.watch(request),
      emitsError(
        isA<LocationSourceException>().having(
          (e) => e.issue,
          'issue',
          LocationIssue.permissionDenied,
        ),
      ),
    );
    expect(calls, 1);
  });

  test('membatalkan fallback menghentikan langganan native', () async {
    var listening = false;
    final native = StreamController<Position>(
      onListen: () => listening = true,
      onCancel: () => listening = false,
    );
    final source = GeolocatorPositionSource(
      serviceEnabled: () async => true,
      positionStream: (settings) => settings.forceLocationManager
          ? native.stream
          : Stream.error(const LocationServiceDisabledException()),
    );
    final subscription = source.watch(request).listen((_) {});
    await pumpEventQueue();
    expect(listening, isTrue);
    await subscription.cancel().timeout(const Duration(seconds: 1));
    expect(listening, isFalse);
    await native.close();
  });

  test('cancel saat memeriksa GPS tidak memulai fallback terlambat', () async {
    final enabled = Completer<bool>();
    var calls = 0;
    final source = GeolocatorPositionSource(
      serviceEnabled: () => enabled.future,
      positionStream: (_) {
        calls++;
        return Stream.error(const LocationServiceDisabledException());
      },
    );
    final subscription = source.watch(request).listen((_) {});
    await pumpEventQueue();
    await subscription.cancel().timeout(const Duration(seconds: 1));
    enabled.complete(true);
    await pumpEventQueue();
    expect(calls, 1);
  });
}
