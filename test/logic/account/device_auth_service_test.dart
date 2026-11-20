import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/logic/account/auth_gateway.dart';
import 'package:agam/logic/account/device_auth_service.dart';
import 'package:agam/logic/account/profile_store.dart';
import 'package:agam/logic/settings/device_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS. Email, password, dan UID fiktif.

class _FakeGateway implements AuthGateway {
  final _users = <String, ({String password, AuthUser user})>{};
  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;
  int _next = 1;
  bool offline = false;
  final calls = <String>[];

  void seed(String email, String password, {String? uid}) {
    final user = AuthUser(uid: uid ?? 'uid-${_next++}', email: email);
    _users[email] = (password: password, user: user);
  }

  void restoreAs(String email) => _current = _users[email]!.user;

  void externalSignOut() {
    _current = null;
    _changes.add(null);
  }

  void _online() {
    if (offline) throw const AuthException(AuthErrorCode.network);
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) async {
    _online();
    if (_users.containsKey(email)) {
      throw const AuthException(AuthErrorCode.emailAlreadyInUse);
    }
    seed(email, password);
    calls.add('create');
    return _current = _users[email]!.user;
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    _online();
    final entry = _users[email];
    if (entry == null || entry.password != password) {
      throw const AuthException(AuthErrorCode.wrongCredentials);
    }
    return _current = entry.user;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _current = null;
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    _online();
    if (!_users.containsKey(email)) {
      throw const AuthException(AuthErrorCode.wrongCredentials);
    }
    calls.add('reset');
  }

  @override
  Future<void> reauthenticate({required String password}) async {
    _online();
    final entry = _users[_current!.email]!;
    if (entry.password != password) {
      throw const AuthException(AuthErrorCode.wrongCredentials);
    }
  }

  @override
  Future<void> deleteCurrentUser() async {
    calls.add('deleteUser');
    _users.remove(_current?.email);
    _current = null;
  }
}

class _MemoryProfiles implements ProfileStore {
  final roles = <String, UserRole>{};
  bool offline = false;
  bool failCreate = false;

  @override
  Future<void> create({required String uid, required UserRole role}) async {
    if (failCreate) throw const AuthException(AuthErrorCode.network);
    roles[uid] = role;
  }

  @override
  Future<UserRole?> read(String uid) async {
    if (offline) throw const AuthException(AuthErrorCode.network);
    return roles[uid];
  }

  @override
  Future<void> delete(String uid) async => roles.remove(uid);
}

class _MemoryKeyValue implements KeyValueStore {
  final values = <String, Object>{};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  late _FakeGateway gateway;
  late _MemoryProfiles profiles;
  late _MemoryKeyValue keyValue;
  late FakeActivityLogger activity;
  late List<String> hooks;
  late DeviceAuthService auth;

  DeviceAuthService build() => DeviceAuthService(
    gateway: gateway,
    profiles: profiles,
    local: LocalAccountStore(store: keyValue),
    activity: activity,
    beforeSignOut: () async => hooks.add('beforeSignOut'),
    flushLogs: () async => hooks.add('flush'),
    beforeDelete: () async => hooks.add('beforeDelete'),
    deleteRemoteLogs: (uid) async => hooks.add('deleteLogs:$uid'),
    clearLocalData: (uid) async => hooks.add('clearLocal:$uid'),
  );

  setUp(() {
    gateway = _FakeGateway();
    profiles = _MemoryProfiles();
    keyValue = _MemoryKeyValue();
    activity = FakeActivityLogger();
    hooks = [];
    auth = build();
  });

  group('daftar', () {
    test('membuat profil, login, lalu mencatat signUp dengan role', () async {
      final account = await auth.signUp(
        email: 'a@contoh.test',
        password: 'rahasia1',
        role: UserRole.pengunjung,
      );
      expect(auth.current.account?.uid, account.uid);
      expect(profiles.roles[account.uid], UserRole.pengunjung);
      expect(activity.events.single, isA<SignUpEvent>());
      expect((activity.events.single as SignUpEvent).role, UserRole.pengunjung);
    });

    test(
      'profil gagal dibuat: akun Auth dibatalkan dan error diteruskan',
      () async {
        profiles.failCreate = true;
        await expectLater(
          auth.signUp(
            email: 'a@contoh.test',
            password: 'rahasia1',
            role: UserRole.mahasiswaItb,
          ),
          throwsA(
            isA<AuthException>().having(
              (e) => e.code,
              'code',
              AuthErrorCode.network,
            ),
          ),
        );
        expect(gateway.calls, contains('deleteUser'));
        expect(auth.current.isSignedIn, isFalse);
        expect(activity.events, isEmpty);
      },
    );

    test('email sudah terdaftar diteruskan sebagai kode kontrak', () async {
      gateway.seed('a@contoh.test', 'rahasia1');
      await expectLater(
        auth.signUp(
          email: 'a@contoh.test',
          password: 'lain123',
          role: UserRole.pengunjung,
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.emailAlreadyInUse,
          ),
        ),
      );
    });
  });

  group('login', () {
    setUp(() {
      gateway.seed('a@contoh.test', 'rahasia1', uid: 'uid-a');
      profiles.roles['uid-a'] = UserRole.mahasiswaItb;
    });

    test('memuat role dari profil dan mencatat login', () async {
      final account = await auth.login(
        email: 'a@contoh.test',
        password: 'rahasia1',
      );
      expect(account.role, UserRole.mahasiswaItb);
      expect(activity.events.single, isA<LoginEvent>());
    });

    test('password salah: tetap keluar dan tidak ada log', () async {
      await expectLater(
        auth.login(email: 'a@contoh.test', password: 'salah'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.wrongCredentials,
          ),
        ),
      );
      expect(auth.current.isSignedIn, isFalse);
      expect(activity.events, isEmpty);
    });

    test('login pertama tanpa jaringan memberi kode network', () async {
      gateway.offline = true;
      await expectLater(
        auth.login(email: 'a@contoh.test', password: 'rahasia1'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.network,
          ),
        ),
      );
    });

    test('profil tidak ada: keluar lagi dan gagal unknown', () async {
      profiles.roles.clear();
      await expectLater(
        auth.login(email: 'a@contoh.test', password: 'rahasia1'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.unknown,
          ),
        ),
      );
      expect(gateway.currentUser, isNull);
    });
  });

  group('pemulihan sesi saat cold start', () {
    setUp(() {
      gateway.seed('a@contoh.test', 'rahasia1', uid: 'uid-a');
      profiles.roles['uid-a'] = UserRole.pengunjung;
    });

    test(
      'mode pesawat setelah login pertama tetap masuk dari salinan lokal',
      () async {
        await auth.login(email: 'a@contoh.test', password: 'rahasia1');

        // Aplikasi ditutup lalu dibuka dalam mode pesawat.
        final reopened = build();
        gateway.restoreAs('a@contoh.test');
        profiles.offline = true;
        await reopened.restore();
        expect(reopened.current.account?.role, UserRole.pengunjung);
      },
    );

    test('tanpa salinan lokal dan tanpa jaringan: kembali ke login', () async {
      gateway.restoreAs('a@contoh.test');
      profiles.offline = true;
      await auth.restore();
      expect(auth.current.isSignedIn, isFalse);
      expect(gateway.calls, contains('signOut'));
    });

    test('pemulihan tidak mencatat event login', () async {
      gateway.restoreAs('a@contoh.test');
      await auth.restore();
      expect(auth.current.isSignedIn, isTrue);
      expect(activity.events, isEmpty);
    });

    test('akun keluar dari luar aplikasi memancarkan signedOut', () async {
      gateway.restoreAs('a@contoh.test');
      await auth.restore();
      final states = <bool>[];
      final sub = auth.state.listen((s) => states.add(s.isSignedIn));
      gateway.externalSignOut();
      await pumpEventQueue();
      expect(states, [true, false]);
      await sub.cancel();
    });
  });

  group('logout', () {
    test(
      'mengakhiri sesi, mencatat logout, mengirim log, lalu keluar',
      () async {
        gateway.seed('a@contoh.test', 'rahasia1', uid: 'uid-a');
        profiles.roles['uid-a'] = UserRole.pengunjung;
        await auth.login(email: 'a@contoh.test', password: 'rahasia1');
        activity.events.clear();

        await auth.logout();
        expect(hooks, ['beforeSignOut', 'flush']);
        expect(activity.events.single, isA<LogoutEvent>());
        expect(gateway.calls.last, 'signOut');
        expect(auth.current.isSignedIn, isFalse);
      },
    );

    test('logout tanpa akun tidak melakukan apa pun', () async {
      await auth.logout();
      expect(hooks, isEmpty);
      expect(activity.events, isEmpty);
    });
  });

  group('lupa password', () {
    test('email tidak terdaftar tidak diungkap', () async {
      await auth.sendPasswordReset(email: 'tidak-ada@contoh.test');
    });

    test('tanpa jaringan diteruskan agar UI dapat memberi tahu', () async {
      gateway.offline = true;
      await expectLater(
        auth.sendPasswordReset(email: 'a@contoh.test'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('hapus akun', () {
    setUp(() async {
      gateway.seed('a@contoh.test', 'rahasia1', uid: 'uid-a');
      profiles.roles['uid-a'] = UserRole.pengunjung;
      await auth.login(email: 'a@contoh.test', password: 'rahasia1');
      activity.events.clear();
    });

    test('menghapus log, profil, data lokal, lalu akun Auth', () async {
      await auth.deleteAccount(password: 'rahasia1');
      expect(hooks, ['beforeDelete', 'deleteLogs:uid-a', 'clearLocal:uid-a']);
      expect(profiles.roles, isEmpty);
      expect(keyValue.values, isEmpty);
      expect(gateway.calls.last, 'deleteUser');
      expect(auth.current.isSignedIn, isFalse);
      expect(activity.events, isEmpty);
    });

    test('password salah: tidak ada yang dihapus', () async {
      await expectLater(
        auth.deleteAccount(password: 'salah'),
        throwsA(isA<AuthException>()),
      );
      expect(hooks, isEmpty);
      expect(profiles.roles, isNotEmpty);
      expect(auth.current.isSignedIn, isTrue);
    });
  });

  test('kode Firebase dipetakan tanpa membedakan email/password salah', () {
    for (final code in [
      'invalid-credential',
      'invalid-login-credentials',
      'wrong-password',
      'user-not-found',
    ]) {
      expect(
        authErrorCodeFor(code),
        AuthErrorCode.wrongCredentials,
        reason: code,
      );
    }
    expect(authErrorCodeFor('network-request-failed'), AuthErrorCode.network);
    expect(authErrorCodeFor('weak-password'), AuthErrorCode.weakPassword);
    expect(authErrorCodeFor('invalid-email'), AuthErrorCode.invalidEmail);
    expect(
      authErrorCodeFor('email-already-in-use'),
      AuthErrorCode.emailAlreadyInUse,
    );
    expect(
      authErrorCodeFor('too-many-requests'),
      AuthErrorCode.tooManyRequests,
    );
    expect(authErrorCodeFor('sesuatu-lain'), AuthErrorCode.unknown);
  });
}
