import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/logic/account/activity_recorders.dart';
import 'package:agam/logic/account/firestore_activity_logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS. UID dan waktu fiktif.

/// Field yang diizinkan `firestore.rules` (`hasExactly`) per event.
const _allowedFields = {
  'signUp': {'uid', 'type', 'at', 'role'},
  'login': {'uid', 'type', 'at'},
  'logout': {'uid', 'type', 'at'},
  'appOpen': {
    'uid',
    'type',
    'at',
    'appVersion',
    'androidVersion',
    'deviceModel',
  },
  'modeStart': {'uid', 'type', 'date', 'mode'},
  'modeEnd': {'uid', 'type', 'date', 'mode', 'durationMin'},
  'featureUsed': {'uid', 'type', 'at', 'feature'},
  'trailCompleted': {'uid', 'type', 'date'},
};

class _ManualSession implements SessionController {
  final _state = StreamController<SessionState>.broadcast();
  SessionState _current = const SessionState.idle();

  Future<void> emit(SessionMode mode) async {
    _current = mode == SessionMode.none
        ? const SessionState.idle()
        : SessionState(mode: mode);
    _state.add(_current);
    await pumpEventQueue();
  }

  @override
  SessionState get current => _current;

  @override
  Stream<SessionState> get state => _state.stream;

  @override
  Stream<PoiTriggerEvent> get triggers => const Stream.empty();

  @override
  Future<void> start(SessionMode mode) => emit(mode);

  @override
  Future<void> end() => emit(SessionMode.none);
}

void main() {
  final now = DateTime(2026, 11, 17, 9, 41);

  group('dokumen log sesuai PRD §15.5 dan firestore.rules', () {
    final events = <ActivityEvent>[
      const ActivityEvent.signUp(role: UserRole.mahasiswaItb),
      const ActivityEvent.login(),
      const ActivityEvent.logout(),
      const ActivityEvent.appOpen(
        appVersion: '1.0.0',
        androidVersion: '14',
        deviceModel: 'SINTETIS',
      ),
      const ActivityEvent.modeStart(mode: ActivityMode.explore),
      ActivityEvent.modeEnd(
        mode: ActivityMode.trail,
        duration: const Duration(minutes: 23),
      ),
      const ActivityEvent.featureUsed(feature: ActivityFeature.search),
      const ActivityEvent.trailCompleted(),
    ];

    for (final event in events) {
      test('${event.type}: hanya field yang diizinkan', () {
        final doc = activityLogDocument(event, uid: 'uid-a', now: now);
        expect(doc.keys.toSet(), _allowedFields[event.type]);
        expect(doc['uid'], 'uid-a');
        if (doc.containsKey('at')) expect(doc['at'], isA<Timestamp>());
        if (doc.containsKey('date')) expect(doc['date'], '2026-11-17');
      });
    }

    test('modeEnd membawa durasi kelipatan 5 menit', () {
      final doc = activityLogDocument(
        ActivityEvent.modeEnd(
          mode: ActivityMode.explore,
          duration: const Duration(minutes: 23),
        ),
        uid: 'uid-a',
        now: now,
      );
      expect(doc['durationMin'], 25);
    });

    test('tanggal memakai nol di depan', () {
      expect(activityDate(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
    });
  });

  group('FirestoreActivityLogger', () {
    late FakeFirebaseFirestore firestore;
    String? uid;
    late FirestoreActivityLogger logger;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      uid = 'uid-a';
      logger = FirestoreActivityLogger(
        currentUid: () => uid,
        firestore: firestore,
        clock: () => now,
      );
    });

    Future<List<Map<String, dynamic>>> logs() async =>
        (await firestore.collection('activity_logs').get()).docs
            .map((d) => d.data())
            .toList();

    test('menulis ke activity_logs tanpa ditunggu', () async {
      logger.log(const ActivityEvent.login());
      await pumpEventQueue();
      final all = await logs();
      expect(all.single['type'], 'login');
      expect(all.single['uid'], 'uid-a');
    });

    test('tanpa akun yang login, event diabaikan', () async {
      uid = null;
      logger.log(const ActivityEvent.login());
      await pumpEventQueue();
      expect(await logs(), isEmpty);
    });

    test('hapus akun hanya menghapus log milik akun tersebut', () async {
      logger.log(const ActivityEvent.login());
      uid = 'uid-b';
      logger.log(const ActivityEvent.login());
      await pumpEventQueue();

      await logger.deleteAllFor('uid-a');
      final remaining = await logs();
      expect(remaining.map((d) => d['uid']), ['uid-b']);
    });
  });

  group('SessionActivityRecorder', () {
    late _ManualSession session;
    late FakeActivityLogger activity;
    late DateTime clock;
    late SessionActivityRecorder recorder;

    setUp(() {
      session = _ManualSession();
      activity = FakeActivityLogger();
      clock = now;
      recorder = SessionActivityRecorder(
        session: session,
        activity: activity,
        clock: () => clock,
      )..start();
    });

    tearDown(() => recorder.dispose());

    test('mulai dan akhir sesi dengan durasi dibulatkan', () async {
      await session.start(SessionMode.explore);
      clock = clock.add(const Duration(minutes: 12));
      await session.end();

      expect(activity.events, hasLength(2));
      final start = activity.events[0] as ModeStartEvent;
      final end = activity.events[1] as ModeEndEvent;
      expect(start.mode, ActivityMode.explore);
      expect(end.mode, ActivityMode.explore);
      expect(end.durationMin, 10);
    });

    test(
      'ganti mode tanpa mengakhiri sesi: akhir lama lalu awal baru',
      () async {
        await session.start(SessionMode.explore);
        clock = clock.add(const Duration(minutes: 5));
        await session.start(SessionMode.navigation);
        expect(activity.events.map((e) => e.type), [
          'modeStart',
          'modeEnd',
          'modeStart',
        ]);
        expect(
          (activity.events.last as ModeStartEvent).mode,
          ActivityMode.navigation,
        );
      },
    );

    test('state yang sama berulang tidak dicatat ulang', () async {
      await session.start(SessionMode.trail);
      await session.start(SessionMode.trail);
      expect(activity.events, hasLength(1));
    });

    test('closeOpenMode mencatat akhir sebelum logout, lalu sesi berakhir tanpa duplikat', () async {
      await session.start(SessionMode.explore);
      recorder.closeOpenMode();
      await session.end();
      expect(activity.events.map((e) => e.type), ['modeStart', 'modeEnd']);
    });

    test('discardOpenMode (hapus akun) tidak mencatat akhir', () async {
      await session.start(SessionMode.explore);
      recorder.discardOpenMode();
      await session.end();
      expect(activity.events.map((e) => e.type), ['modeStart']);
    });
  });

  group('AppOpenRecorder', () {
    late FakeAuthService auth;
    late FakeActivityLogger activity;

    Future<AppOpenInfo> info() async =>
        (appVersion: '1.0.0', androidVersion: '14', deviceModel: 'SINTETIS');

    setUp(() {
      activity = FakeActivityLogger();
      auth = FakeAuthService();
    });

    test('sudah login saat cold start: dicatat sekali', () async {
      auth = FakeAuthService(
        signedInAs: const UserAccount(
          uid: 'uid-a',
          email: 'a@contoh.test',
          role: UserRole.pengunjung,
        ),
      );
      final recorder = AppOpenRecorder(
        auth: auth,
        activity: activity,
        info: info,
        launchedFromNotification: () async => false,
      );
      await recorder.start();
      await pumpEventQueue();
      await auth.logout();
      await pumpEventQueue();
      expect(activity.events.whereType<AppOpenEvent>(), hasLength(1));
      await recorder.dispose();
    });

    test(
      'belum login: dicatat saat login pertama di proses yang sama',
      () async {
        final recorder = AppOpenRecorder(
          auth: auth,
          activity: activity,
          info: info,
          launchedFromNotification: () async => false,
        );
        await recorder.start();
        await pumpEventQueue();
        expect(activity.events, isEmpty);

        await auth.signUp(
          email: 'a@contoh.test',
          password: 'rahasia1',
          role: UserRole.pengunjung,
        );
        await pumpEventQueue();
        final open = activity.events.whereType<AppOpenEvent>().single;
        expect(open.deviceModel, 'SINTETIS');
        await recorder.dispose();
      },
    );

    test('dibuka dari notifikasi trigger: tidak dicatat', () async {
      auth = FakeAuthService(
        signedInAs: const UserAccount(
          uid: 'uid-a',
          email: 'a@contoh.test',
          role: UserRole.pengunjung,
        ),
      );
      final recorder = AppOpenRecorder(
        auth: auth,
        activity: activity,
        info: info,
        launchedFromNotification: () async => true,
      );
      await recorder.start();
      await pumpEventQueue();
      expect(activity.events, isEmpty);
      await recorder.dispose();
    });

    test('nilai perangkat dipotong 64 karakter dan tidak kosong', () {
      expect(shortField('  '), 'unknown');
      expect(shortField('x' * 80).length, 64);
      expect(shortField(' Pixel 8 '), 'Pixel 8');
    });
  });
}
