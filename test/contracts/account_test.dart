import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:flutter_test/flutter_test.dart';

// Akun, email, dan password SINTETIS.
void main() {
  group('ActivityEvent sesuai PRD §15.5', () {
    // Daftar ditulis ulang dari tabel PRD §15.5, bukan disalin dari kode.
    final cases = <ActivityEvent, (String, Set<String>, ActivityTimePrecision)>{
      const ActivityEvent.signUp(role: UserRole.pengunjung): (
        'signUp',
        {'role'},
        ActivityTimePrecision.instant,
      ),
      const ActivityEvent.login(): ('login', {}, ActivityTimePrecision.instant),
      const ActivityEvent.logout(): (
        'logout',
        {},
        ActivityTimePrecision.instant,
      ),
      const ActivityEvent.appOpen(
        appVersion: '0.0.0',
        androidVersion: '14',
        deviceModel: 'SINTETIS',
      ): (
        'appOpen',
        {'appVersion', 'androidVersion', 'deviceModel'},
        ActivityTimePrecision.instant,
      ),
      const ActivityEvent.modeStart(mode: ActivityMode.explore): (
        'modeStart',
        {'mode'},
        ActivityTimePrecision.dateOnly,
      ),
      ActivityEvent.modeEnd(
        mode: ActivityMode.trail,
        duration: const Duration(minutes: 12),
      ): (
        'modeEnd',
        {'mode', 'durationMin'},
        ActivityTimePrecision.dateOnly,
      ),
      const ActivityEvent.featureUsed(feature: ActivityFeature.search): (
        'featureUsed',
        {'feature'},
        ActivityTimePrecision.instant,
      ),
      const ActivityEvent.trailCompleted(): (
        'trailCompleted',
        {},
        ActivityTimePrecision.dateOnly,
      ),
    };

    test('mencakup kedelapan event', () {
      expect(cases.values.map((c) => c.$1).toSet(), hasLength(8));
    });

    for (final MapEntry(key: event, value: (type, keys, precision))
        in cases.entries) {
      test('$type: type, field, dan ketelitian waktu', () {
        expect(event.type, type);
        expect(event.fields.keys.toSet(), keys);
        expect(event.timePrecision, precision);
      });
    }

    test('tidak ada event yang membawa field terlarang', () {
      const forbidden = {
        'lat',
        'lng',
        'position',
        'poiId',
        'poiName',
        'destination',
        'origin',
        'query',
        'reason',
        'endReason',
        'at',
        'date',
        'uid',
        'type',
      };
      for (final event in cases.keys) {
        expect(
          event.fields.keys.toSet().intersection(forbidden),
          isEmpty,
          reason: event.type,
        );
      }
    });

    test('nilai enum ditulis persis seperti PRD', () {
      expect(const ActivityEvent.signUp(role: UserRole.mahasiswaItb).fields, {
        'role': 'mahasiswaItb',
      });
      expect(
        const ActivityEvent.modeStart(mode: ActivityMode.navigation).fields,
        {'mode': 'navigation'},
      );
      expect(
        const ActivityEvent.featureUsed(
          feature: ActivityFeature.poiCard,
        ).fields,
        {'feature': 'poiCard'},
      );
      expect(ActivityFeature.values.map((f) => f.name), [
        'search',
        'poiCard',
        'narration',
        'facilities',
      ]);
    });
  });

  group('modeEnd.durationMin dibulatkan ke 5 menit terdekat', () {
    final cases = <Duration, int>{
      Duration.zero: 0,
      const Duration(minutes: 2, seconds: 29): 0,
      const Duration(minutes: 2, seconds: 30): 5,
      const Duration(minutes: 7, seconds: 29): 5,
      const Duration(minutes: 7, seconds: 30): 10,
      const Duration(minutes: 62): 60,
      const Duration(hours: 2, minutes: 3): 125,
      const Duration(minutes: -3): 0,
    };
    for (final MapEntry(key: duration, value: expected) in cases.entries) {
      test('$duration → $expected', () {
        final event = ModeEndEvent(
          mode: ActivityMode.explore,
          duration: duration,
        );
        expect(event.durationMin, expected);
        expect(event.fields['durationMin'], expected);
      });
    }
  });

  test('ActivityMode.fromSession: peta biasa tidak dicatat', () {
    expect(ActivityMode.fromSession(SessionMode.none), isNull);
    expect(ActivityMode.fromSession(SessionMode.explore), ActivityMode.explore);
    expect(
      ActivityMode.fromSession(SessionMode.navigation),
      ActivityMode.navigation,
    );
    expect(ActivityMode.fromSession(SessionMode.trail), ActivityMode.trail);
  });

  group('FakeAuthService', () {
    late FakeActivityLogger activity;
    late FakeAuthService auth;

    setUp(() {
      activity = FakeActivityLogger();
      auth = FakeAuthService(activity: activity);
    });

    Future<AuthErrorCode?> errorOf(Future<Object?> Function() action) async {
      try {
        await action();
        return null;
      } on AuthException catch (e) {
        return e.code;
      }
    }

    test('mulai belum login dan state langsung memancarkan keadaan', () async {
      expect(auth.current.isSignedIn, isFalse);
      expect((await auth.state.first).isSignedIn, isFalse);
    });

    test('daftar → login otomatis, role tersimpan, event signUp', () async {
      final states = <AuthState>[];
      final subscription = auth.state.listen(states.add);

      final account = await auth.signUp(
        email: ' Uji@Contoh.test ',
        password: 'rahasia1',
        role: UserRole.mahasiswaItb,
      );
      await pumpEventQueue();

      expect(account.email, 'uji@contoh.test');
      expect(account.role, UserRole.mahasiswaItb);
      expect(auth.current.account?.uid, account.uid);
      expect(states.map((s) => s.isSignedIn), [false, true]);
      expect(activity.events.single, isA<SignUpEvent>());
      await subscription.cancel();
    });

    test('logout dicatat sebelum keluar, lalu login kembali', () async {
      final account = await auth.signUp(
        email: 'uji@contoh.test',
        password: 'rahasia1',
        role: UserRole.pengunjung,
      );
      await auth.logout();
      expect(auth.current.isSignedIn, isFalse);

      final again = await auth.login(
        email: 'uji@contoh.test',
        password: 'rahasia1',
      );
      expect(again.uid, account.uid);
      expect(activity.events.map((e) => e.type), ['signUp', 'logout', 'login']);
    });

    test('kegagalan dipetakan ke AuthErrorCode', () async {
      await auth.signUp(
        email: 'uji@contoh.test',
        password: 'rahasia1',
        role: UserRole.pengunjung,
      );
      await auth.logout();

      expect(
        await errorOf(
          () => auth.signUp(
            email: 'bukan-email',
            password: 'rahasia1',
            role: UserRole.pengunjung,
          ),
        ),
        AuthErrorCode.invalidEmail,
      );
      expect(
        await errorOf(
          () => auth.signUp(
            email: 'lain@contoh.test',
            password: '12345',
            role: UserRole.pengunjung,
          ),
        ),
        AuthErrorCode.weakPassword,
      );
      expect(
        await errorOf(
          () => auth.signUp(
            email: 'uji@contoh.test',
            password: 'rahasia1',
            role: UserRole.pengunjung,
          ),
        ),
        AuthErrorCode.emailAlreadyInUse,
      );
      // Email tidak terdaftar dan password salah tidak dibedakan.
      expect(
        await errorOf(
          () => auth.login(email: 'uji@contoh.test', password: 'salah123'),
        ),
        AuthErrorCode.wrongCredentials,
      );
      expect(
        await errorOf(
          () => auth.login(email: 'tidak@ada.test', password: 'rahasia1'),
        ),
        AuthErrorCode.wrongCredentials,
      );
      expect(auth.current.isSignedIn, isFalse);
    });

    test('offline: login gagal dengan kode network', () async {
      auth.offline = true;
      expect(
        await errorOf(
          () => auth.login(email: 'uji@contoh.test', password: 'rahasia1'),
        ),
        AuthErrorCode.network,
      );
    });

    test('reset password tidak mengungkap email terdaftar', () async {
      await auth.sendPasswordReset(email: 'tidak@ada.test');
      expect(
        await errorOf(() => auth.sendPasswordReset(email: 'bukan-email')),
        AuthErrorCode.invalidEmail,
      );
    });

    test(
      'hapus akun butuh password dan akun tidak bisa dipakai lagi',
      () async {
        await auth.signUp(
          email: 'uji@contoh.test',
          password: 'rahasia1',
          role: UserRole.pengunjung,
        );
        expect(
          await errorOf(() => auth.deleteAccount(password: 'salah123')),
          AuthErrorCode.wrongCredentials,
        );
        expect(auth.current.isSignedIn, isTrue);

        await auth.deleteAccount(password: 'rahasia1');
        expect(auth.current.isSignedIn, isFalse);
        expect(
          await errorOf(
            () => auth.login(email: 'uji@contoh.test', password: 'rahasia1'),
          ),
          AuthErrorCode.wrongCredentials,
        );
      },
    );

    test('signedInAs memulai dalam keadaan login', () {
      const account = UserAccount(
        uid: 'fake-uid-x',
        email: 'uji@contoh.test',
        role: UserRole.pengunjung,
      );
      final signedIn = FakeAuthService(signedInAs: account);
      expect(signedIn.current.account?.uid, 'fake-uid-x');
    });
  });

  test('AppServices.fake merangkai auth dengan logger yang sama', () async {
    final services = AppServices.fake();
    await services.auth.signUp(
      email: 'uji@contoh.test',
      password: 'rahasia1',
      role: UserRole.pengunjung,
    );
    final logger = services.activity as FakeActivityLogger;
    expect(logger.events.single.type, 'signUp');
  });
}
