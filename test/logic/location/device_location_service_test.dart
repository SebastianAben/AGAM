import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/location/device_location_service.dart';
import 'package:agam/logic/location/position_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic.dart';

// SINTETIS. Menguji kapan lokasi dibaca (PRD §6), bukan GPS sungguhan.
void main() {
  late RecordingPositionSource source;
  late DeviceLocationService service;

  DeviceLocationService create({bool visible = true}) =>
      DeviceLocationService(source: source, appVisible: visible);

  setUp(() => source = RecordingPositionSource());
  tearDown(() => service.dispose());

  group('mode peta biasa', () {
    test('tanpa pendengar tidak membaca lokasi', () async {
      service = create();
      await pumpEventQueue();
      expect(source.requests, isEmpty);
      expect(service.activeRequest, isNull);
    });

    test(
      'pendengar saat aplikasi tampil memulai pembacaan tanpa service',
      () async {
        service = create();
        final sub = service.positions.listen((_) {});
        await pumpEventQueue();
        expect(source.activeSubscriptions, 1);
        expect(
          source.lastRequest,
          const LocationRequest(
            interval: Duration(seconds: 3),
            sessionService: false,
          ),
        );
        await sub.cancel();
      },
    );

    test(
      'posisi diteruskan dan lastFix dihapus saat pembacaan berhenti',
      () async {
        service = create();
        final received = <LocationFix>[];
        final sub = service.positions.listen(received.add);
        await pumpEventQueue();
        source.emit(syntheticFix(0, metersNorth: 100));
        await pumpEventQueue();
        expect(received, hasLength(1));
        expect(service.lastFix, isNotNull);

        await sub.cancel();
        await pumpEventQueue();
        expect(source.activeSubscriptions, 0);
        expect(service.lastFix, isNull);
      },
    );

    test('aplikasi diminimalkan menghentikan pembacaan', () async {
      service = create();
      final sub = service.positions.listen((_) {});
      await pumpEventQueue();
      await service.setAppVisible(false);
      expect(source.activeSubscriptions, 0);
      expect(service.activeRequest, isNull);

      await service.setAppVisible(true);
      expect(source.activeSubscriptions, 1);
      await sub.cancel();
    });

    test('pendengar saat aplikasi tidak tampil tidak membaca lokasi', () async {
      service = create(visible: false);
      final sub = service.positions.listen((_) {});
      await pumpEventQueue();
      expect(source.requests, isEmpty);
      await sub.cancel();
    });
  });

  group('sesi', () {
    test(
      'memakai foreground service dan tetap berjalan saat layar mati',
      () async {
        service = create();
        await service.beginSession();
        expect(source.lastRequest!.sessionService, isTrue);
        expect(source.activeSubscriptions, 1);

        await service.setAppVisible(false);
        expect(source.activeSubscriptions, 1);
        expect(service.activeRequest!.sessionService, isTrue);
      },
    );

    test('endSession saat layar mati menghentikan seluruh pembacaan', () async {
      service = create();
      await service.beginSession();
      await service.setAppVisible(false);
      await service.endSession();
      expect(source.activeSubscriptions, 0);
      expect(service.activeRequest, isNull);
    });

    test(
      'endSession saat peta masih tampil beralih ke mode peta biasa',
      () async {
        service = create();
        final sub = service.positions.listen((_) {});
        await pumpEventQueue();
        await service.beginSession();
        await service.endSession();
        expect(source.activeSubscriptions, 1);
        expect(service.activeRequest!.sessionService, isFalse);
        await sub.cancel();
      },
    );

    test(
      'memulai sesi saat peta terbuka tidak membuat dua langganan',
      () async {
        service = create();
        final sub = service.positions.listen((_) {});
        await pumpEventQueue();
        await service.beginSession();
        expect(source.activeSubscriptions, 1);
        expect(source.requests, hasLength(2));
        await sub.cancel();
      },
    );

    test('masalah izin dipancarkan lewat issues', () async {
      service = create();
      final issues = <LocationIssue>[];
      final sub = service.issues.listen(issues.add);
      await service.beginSession();
      source.fail(LocationIssue.permissionDenied);
      await pumpEventQueue();
      expect(issues, [LocationIssue.permissionDenied]);
      await sub.cancel();
    });
  });

  group('interval adaptif', () {
    test('diterapkan saat aplikasi tampil', () async {
      service = create()..setPois([syntheticPoi()]);
      await service.beginSession();
      source.emit(syntheticFix(0, metersNorth: 250));
      await pumpEventQueue();
      expect(service.activeRequest!.interval, const Duration(seconds: 10));
      expect(source.activeSubscriptions, 1);

      source.emit(syntheticFix(3, metersNorth: 100));
      await pumpEventQueue();
      expect(service.activeRequest!.interval, const Duration(seconds: 3));
    });

    test('ditunda selama layar mati agar foreground service tidak dimulai '
        'ulang dari latar belakang', () async {
      service = create()..setPois([syntheticPoi()]);
      await service.beginSession();
      await service.setAppVisible(false);
      final before = source.requests.length;

      source.emit(syntheticFix(0, metersNorth: 250));
      await pumpEventQueue();
      expect(source.requests, hasLength(before));
      expect(service.activeRequest!.interval, const Duration(seconds: 3));

      await service.setAppVisible(true);
      expect(service.activeRequest!.interval, const Duration(seconds: 10));
    });
  });

  test('dispose menghentikan pembacaan', () async {
    service = create();
    await service.beginSession();
    await service.dispose();
    expect(source.activeSubscriptions, 0);
    // tearDown memanggil dispose lagi; buat instance baru yang aman.
    service = create();
  });

  test('langganan diganti secara berurutan tanpa tumpang tindih', () async {
    service = create();
    final sub = service.positions.listen((_) {});
    unawaited(service.beginSession());
    unawaited(service.setAppVisible(false));
    unawaited(service.endSession());
    await pumpEventQueue();
    expect(source.activeSubscriptions, 0);
    await sub.cancel();
  });
}
