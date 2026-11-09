import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/logic/location/device_location_service.dart';
import 'package:agam/logic/location/position_source.dart';
import 'package:agam/logic/session/device_session_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic.dart';

// SINTETIS. POI di (0, 0) radius 15 m. "Kampus" sintetis: semua titik
// dengan lintang < 0,009° (≈1.000 m di utara POI).
bool _insideSyntheticCampus(GeoPoint p) => p.lat < 0.009;

void main() {
  late RecordingPositionSource source;
  late DeviceLocationService location;
  late DeviceSessionController session;
  late List<PoiTriggerEvent> triggers;
  late StreamSubscription<PoiTriggerEvent> triggerSub;

  void setUpSession() {
    source = RecordingPositionSource();
    location = DeviceLocationService(source: source, appVisible: false);
    session = DeviceSessionController(
      location: location,
      pois: FakePoiRepository(pois: [syntheticPoi()]),
      isInsideCampus: _insideSyntheticCampus,
      clock: () => syntheticEpoch,
    );
    triggers = [];
    triggerSub = session.triggers.listen(triggers.add);
  }

  /// Mengirim pembacaan di dalam radius selama [seconds] detik, tiap 1 detik.
  Future<void> dwell(double from, double seconds) async {
    for (var t = from; t <= from + seconds; t++) {
      source.emit(syntheticFix(t, metersNorth: 5));
    }
    await pumpEventQueue();
  }

  group('mulai dan akhiri', () {
    setUp(setUpSession);
    tearDown(() async {
      await triggerSub.cancel();
      await session.dispose();
      await location.dispose();
    });

    test('start(none) ditolak', () {
      expect(() => session.start(SessionMode.none), throwsArgumentError);
    });

    test('start memulai pembacaan lokasi dengan foreground service', () async {
      await session.start(SessionMode.explore);
      expect(session.current.mode, SessionMode.explore);
      expect(session.current.startedAt, syntheticEpoch);
      expect(source.activeSubscriptions, 1);
      expect(source.lastRequest!.sessionService, isTrue);
    });

    test('mengganti mode tidak memulai ulang service', () async {
      await session.start(SessionMode.explore);
      final requests = source.requests.length;
      await session.start(SessionMode.navigation);
      expect(session.current.mode, SessionMode.navigation);
      expect(session.current.startedAt, syntheticEpoch);
      expect(source.requests, hasLength(requests));
      expect(source.activeSubscriptions, 1);
    });

    test('end menghentikan lokasi dan service', () async {
      final states = <SessionState>[];
      final sub = session.state.listen(states.add);
      await session.start(SessionMode.explore);
      await session.end();
      expect(source.activeSubscriptions, 0);
      expect(session.current.isActive, isFalse);
      expect(session.current.lastEndReason, SessionEndReason.userEnded);
      expect(states.map((s) => s.mode), [
        SessionMode.explore,
        SessionMode.none,
      ]);
      await sub.cancel();
    });

    test('izin dicabut mengakhiri sesi', () async {
      await session.start(SessionMode.explore);
      source.fail(LocationIssue.permissionDenied);
      await pumpEventQueue();
      expect(session.current.isActive, isFalse);
      expect(session.current.lastEndReason, SessionEndReason.permissionRevoked);
      expect(source.activeSubscriptions, 0);
    });

    test('layanan lokasi mati tidak mengakhiri sesi', () async {
      await session.start(SessionMode.explore);
      source.fail(LocationIssue.serviceDisabled);
      await pumpEventQueue();
      expect(session.current.isActive, isTrue);
    });
  });

  group('trigger', () {
    setUp(setUpSession);
    tearDown(() async {
      await triggerSub.cancel();
      await session.dispose();
      await location.dispose();
    });

    test('Explore: dwell 5 detik menghasilkan respons penuh', () async {
      await session.start(SessionMode.explore);
      await dwell(0, 4);
      expect(triggers, isEmpty);
      await dwell(5, 0);
      expect(triggers, hasLength(1));
      expect(triggers.single.poiId, 'synthetic-a');
      expect(triggers.single.mode, SessionMode.explore);
      expect(triggers.single.response, TriggerResponse.full);
      expect(
        triggers.single.triggeredAt,
        syntheticEpoch.add(const Duration(seconds: 5)),
      );
    });

    test('Trail: respons penuh', () async {
      await session.start(SessionMode.trail);
      await dwell(0, 5);
      expect(triggers.single.response, TriggerResponse.full);
    });

    test('Navigasi: respons ringkas tanpa audio', () async {
      await session.start(SessionMode.navigation);
      await dwell(0, 5);
      expect(triggers.single.mode, SessionMode.navigation);
      expect(triggers.single.response, TriggerResponse.brief);
    });

    test('tidak terpicu ulang selama tetap di area', () async {
      await session.start(SessionMode.explore);
      await dwell(0, 60);
      expect(triggers, hasLength(1));
    });

    test('cooldown bertahan setelah sesi diakhiri lalu dimulai lagi', () async {
      await session.start(SessionMode.explore);
      await dwell(0, 5);
      await session.end();
      await session.start(SessionMode.explore);
      await dwell(10, 10);
      expect(triggers, hasLength(1));
      // Setelah 10 menit sejak trigger pertama (detik 5), boleh lagi.
      await dwell(605, 6);
      expect(triggers, hasLength(2));
    });

    test('tidak ada trigger setelah sesi diakhiri', () async {
      await session.start(SessionMode.explore);
      await dwell(0, 3);
      await session.end();
      // Langganan sudah dibatalkan; sumber baru tidak dibuat.
      expect(source.activeSubscriptions, 0);
      expect(triggers, isEmpty);
    });

    test('di luar area kampus trigger tidak aktif', () async {
      // Kampus sintetis kosong: semua titik di luar.
      await triggerSub.cancel();
      await session.dispose();
      session = DeviceSessionController(
        location: location,
        pois: FakePoiRepository(pois: [syntheticPoi()]),
        isInsideCampus: (_) => false,
      );
      triggers = [];
      triggerSub = session.triggers.listen(triggers.add);
      await session.start(SessionMode.explore);
      await dwell(0, 10);
      expect(session.isInsideCampus, isFalse);
      expect(triggers, isEmpty);
    });
  });

  group('auto-end 30 menit di luar kampus', () {
    test('berakhir setelah 30 menit di luar area', () {
      fakeAsync((async) {
        setUpSession();
        session.start(SessionMode.explore);
        async.flushMicrotasks();
        source.emit(syntheticFix(0, metersNorth: 2000));
        async.flushMicrotasks();
        expect(session.isInsideCampus, isFalse);

        async.elapse(const Duration(minutes: 29, seconds: 59));
        expect(session.current.isActive, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(session.current.isActive, isFalse);
        expect(
          session.current.lastEndReason,
          SessionEndReason.outsideCampusTimeout,
        );
        // Penghentian langganan lokasi memakai jalur _end yang sama dengan
        // test end()/izin dicabut di atas. Di dalam fakeAsync, future
        // cancel() bawaan Dart dijadwalkan di zona root sehingga tidak dapat
        // diamati di sini.
      });
    });

    test('kembali ke area membatalkan hitungan', () {
      fakeAsync((async) {
        setUpSession();
        session.start(SessionMode.explore);
        async.flushMicrotasks();
        source.emit(syntheticFix(0, metersNorth: 2000));
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 20));
        source.emit(syntheticFix(1200, metersNorth: 100));
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 20));
        expect(session.current.isActive, isTrue);

        // Keluar lagi: hitungan dimulai dari nol.
        source.emit(syntheticFix(2400, metersNorth: 2000));
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 29));
        expect(session.current.isActive, isTrue);
        async.elapse(const Duration(minutes: 1));
        expect(session.current.isActive, isFalse);
      });
    });

    test('pembacaan tidak akurat tidak memulai hitungan', () {
      fakeAsync((async) {
        setUpSession();
        session.start(SessionMode.explore);
        async.flushMicrotasks();
        source.emit(syntheticFix(0, metersNorth: 2000, accuracy: 500));
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 31));
        expect(session.current.isActive, isTrue);
        expect(session.isInsideCampus, isTrue);
      });
    });

    test('mengakhiri sesi membatalkan hitungan', () {
      fakeAsync((async) {
        setUpSession();
        session.start(SessionMode.explore);
        async.flushMicrotasks();
        source.emit(syntheticFix(0, metersNorth: 2000));
        async.flushMicrotasks();
        session.end();
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 31));
        expect(session.current.lastEndReason, SessionEndReason.userEnded);
      });
    });
  });
}
