import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/location/device_location_service.dart';
import 'package:agam/logic/location/position_source.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic.dart';

// SINTETIS. Menguji kapan lokasi dibaca (PRD §6), bukan GPS sungguhan.
void main() {
  late RecordingPositionSource source;
  late DeviceLocationService service;

  DeviceLocationService create({
    bool visible = true,
    Stream<bool>? status,
    Duration Function(int attempt)? retryDelay,
  }) => DeviceLocationService(
    source: source,
    appVisible: visible,
    serviceStatus: status,
    retryDelay: retryDelay,
  );

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

    test('error menghapus lastFix agar posisi lama tidak dipakai', () async {
      service = create();
      await service.beginSession();
      source.emit(syntheticFix(0));
      await pumpEventQueue();
      expect(service.lastFix, isNotNull);
      source.fail(LocationIssue.serviceDisabled);
      await pumpEventQueue();
      expect(service.lastFix, isNull);
    });

    test('stream berakhir setelah error GPS dapat pulih saat resume', () async {
      service = create();
      await service.beginSession();
      source.fail(LocationIssue.serviceDisabled);
      await source.finish();
      await pumpEventQueue();
      expect(service.activeRequest, isNull);
      expect(source.activeSubscriptions, 0);
      await service.setAppVisible(false);
      await service.setAppVisible(true);
      expect(source.activeSubscriptions, 1);
      expect(service.activeRequest!.sessionService, isTrue);
      source.emit(syntheticFix(10));
      await pumpEventQueue();
      expect(service.lastFix, isNotNull);
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

    test('interval lambat dikembalikan ke normal saat masuk latar belakang '
        'agar dwell sesi tidak gagal', () async {
      service = create()..setPois([syntheticPoi()]);
      await service.beginSession();

      // Di latar depan dan jauh dari POI -> beralih ke slow (10 detik).
      source.emit(syntheticFix(0, metersNorth: 250));
      await pumpEventQueue();
      expect(service.activeRequest!.interval, const Duration(seconds: 10));

      // Beralih ke latar belakang: dikembalikan ke normal (3 detik) sebelum
      // pergantian latar belakang dibekukan.
      await service.setAppVisible(false);
      expect(service.activeRequest!.interval, const Duration(seconds: 3));
      expect(source.activeSubscriptions, 1);

      // Fix berikutnya di latar belakang tidak boleh memperlambat kembali ke 10s.
      final before = source.requests.length;
      source.emit(syntheticFix(3, metersNorth: 250));
      await pumpEventQueue();
      expect(source.requests, hasLength(before));
      expect(service.activeRequest!.interval, const Duration(seconds: 3));

      // Kembali ke latar depan -> interval adaptif kembali diterapkan.
      await service.setAppVisible(true);
      expect(service.activeRequest!.interval, const Duration(seconds: 10));
    });
  });

  group('pemulihan otomatis error transien', () {
    test('error LocationIssue.other memulihkan stream otomatis dengan backoff '
        'dan mereset hitungan setelah fix berhasil', () {
      fakeAsync((async) {
        final attempts = <int>[];
        service = create(
          retryDelay: (attempt) {
            attempts.add(attempt);
            return Duration(seconds: attempt * 2);
          },
        );
        service.beginSession();
        async.flushMicrotasks();
        expect(source.activeSubscriptions, 1);

        // Error transien pertama + stream selesai -> jadwal retry ke-1 (2s).
        source.fail(LocationIssue.other);
        source.finish();
        async.flushMicrotasks();
        expect(service.activeRequest, isNull);
        expect(source.activeSubscriptions, 0);
        expect(attempts, [1]);

        async.elapse(const Duration(seconds: 1));
        expect(source.activeSubscriptions, 0);
        async.elapse(const Duration(seconds: 1));
        expect(source.activeSubscriptions, 1);
        expect(service.activeRequest!.sessionService, isTrue);

        // Error transien kedua berturut-turut -> backoff retry ke-2 (4s).
        source.fail(LocationIssue.other);
        source.finish();
        async.flushMicrotasks();
        expect(attempts, [1, 2]);
        async.elapse(const Duration(seconds: 3));
        expect(source.activeSubscriptions, 0);
        async.elapse(const Duration(seconds: 1));
        expect(source.activeSubscriptions, 1);

        // Fix berhasil mereset hitungan backoff kembali ke 1.
        source.emit(syntheticFix(10));
        async.flushMicrotasks();
        expect(service.lastFix, isNotNull);

        source.fail(LocationIssue.other);
        source.finish();
        async.flushMicrotasks();
        expect(attempts, [1, 2, 1]);
        async.elapse(const Duration(seconds: 2));
        expect(source.activeSubscriptions, 1);
      });
      service = create();
    });

    test('stream berakhir mendadak tanpa error juga pulih otomatis', () {
      fakeAsync((async) {
        service = create(retryDelay: (_) => const Duration(seconds: 2));
        service.beginSession();
        async.flushMicrotasks();

        source.finish();
        async.flushMicrotasks();
        expect(source.activeSubscriptions, 0);

        async.elapse(const Duration(seconds: 2));
        expect(source.activeSubscriptions, 1);
      });
      service = create();
    });

    test('error permissionDenied dan serviceDisabled tidak retry otomatis', () {
      fakeAsync((async) {
        for (final issue in [
          LocationIssue.permissionDenied,
          LocationIssue.serviceDisabled,
        ]) {
          source = RecordingPositionSource();
          service = create(retryDelay: (_) => const Duration(seconds: 1));
          service.beginSession();
          async.flushMicrotasks();
          source.fail(issue);
          source.finish();
          async.flushMicrotasks();
          async.elapse(const Duration(minutes: 1));
          expect(source.activeSubscriptions, 0);
          expect(source.requests, hasLength(1));
        }
      });
      service = create();
    });

    test('endSession dan dispose membatalkan timer retry yang tertunda', () {
      fakeAsync((async) {
        service = create(retryDelay: (_) => const Duration(seconds: 5));
        service.beginSession();
        async.flushMicrotasks();

        source.fail(LocationIssue.other);
        source.finish();
        async.flushMicrotasks();
        expect(source.requests, hasLength(1));

        service.endSession();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        expect(source.requests, hasLength(1));
        expect(source.activeSubscriptions, 0);
      });
      service = create();
    });
  });

  group('pemulihan status GPS', () {
    test('GPS aktif memulihkan peta tanpa harus background/resume', () async {
      final status = StreamController<bool>.broadcast();
      service = create(status: status.stream);
      final sub = service.positions.listen((_) {});
      await pumpEventQueue();
      source.emit(syntheticFix(0));
      await pumpEventQueue();
      status.add(false);
      source.fail(LocationIssue.serviceDisabled);
      await source.finish();
      await pumpEventQueue();
      expect(service.lastFix, isNull);
      expect(source.activeSubscriptions, 0);
      status.add(true);
      await pumpEventQueue();
      expect(source.activeSubscriptions, 1);
      source.emit(syntheticFix(10));
      await pumpEventQueue();
      expect(service.lastFix, isNotNull);
      await sub.cancel();
      await status.close();
    });

    test(
      'GPS aktif di background tidak memulai foreground service baru',
      () async {
        final status = StreamController<bool>.broadcast();
        service = create(status: status.stream);
        await service.beginSession();
        await service.setAppVisible(false);
        status.add(false);
        source.fail(LocationIssue.serviceDisabled);
        await source.finish();
        await pumpEventQueue();
        final requests = source.requests.length;
        status.add(true);
        await pumpEventQueue();
        expect(source.requests, hasLength(requests));
        expect(source.activeSubscriptions, 0);
        await service.setAppVisible(true);
        expect(source.activeSubscriptions, 1);
        expect(service.activeRequest!.sessionService, isTrue);
        await status.close();
      },
    );

    test('status GPS tidak membaca posisi tanpa pendengar atau sesi', () async {
      final status = StreamController<bool>.broadcast();
      service = create(status: status.stream);
      status.add(false);
      status.add(true);
      await pumpEventQueue();
      expect(source.requests, isEmpty);
      await service.dispose();
      expect(status.hasListener, isFalse);
      await status.close();
      service = create();
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
