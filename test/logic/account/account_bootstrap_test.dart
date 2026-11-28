import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/logic/account/account_bootstrap.dart';
import 'package:agam/logic/account/auth_gateway.dart';
import 'package:agam/logic/account/profile_store.dart';
import 'package:agam/logic/settings/device_settings_store.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS. Email, password, dan UID fiktif untuk verifikasi perangkaian akun.

class _TestGateway implements AuthGateway {
  final _users = <String, ({String password, AuthUser user})>{};
  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  void seed(String email, String password, {required String uid}) {
    _users[email] = (
      password: password,
      user: AuthUser(uid: uid, email: email),
    );
  }

  void externalSignOut() {
    _current = null;
    _changes.add(null);
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
    final user = AuthUser(uid: 'uid-${_users.length + 1}', email: email);
    _users[email] = (password: password, user: user);
    return _current = user;
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final entry = _users[email];
    if (entry == null || entry.password != password) {
      throw const AuthException(AuthErrorCode.wrongCredentials);
    }
    return _current = entry.user;
  }

  @override
  Future<void> signOut() async {
    _current = null;
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  @override
  Future<void> reauthenticate({required String password}) async {
    final entry = _users[_current!.email]!;
    if (entry.password != password) {
      throw const AuthException(AuthErrorCode.wrongCredentials);
    }
  }

  @override
  Future<void> deleteCurrentUser() async {
    _users.remove(_current?.email);
    _current = null;
  }

  Future<void> dispose() => _changes.close();
}

class _TestProfiles implements ProfileStore {
  final roles = <String, UserRole>{};

  @override
  Future<void> create({required String uid, required UserRole role}) async {
    roles[uid] = role;
  }

  @override
  Future<UserRole?> read(String uid) async => roles[uid];

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
  late _TestGateway gateway;
  late _TestProfiles profiles;
  late _MemoryKeyValue keyValue;
  late FakeLocationService location;
  late FakeSessionController session;
  late FakeAudioService audio;
  late DeviceSettingsStore settings;
  late LaAccountServices services;

  setUp(() async {
    gateway = _TestGateway()..seed('a@contoh.test', 'rahasia1', uid: 'uid-a');
    profiles = _TestProfiles()..roles['uid-a'] = UserRole.pengunjung;
    keyValue = _MemoryKeyValue();
    location = FakeLocationService();
    session = FakeSessionController(location: location);
    audio = FakeAudioService();
    settings = DeviceSettingsStore(store: keyValue);
    await settings.load();

    services = await wireLaAccountServices(
      session: session,
      audio: audio,
      settings: settings,
      launchedFromNotification: () async => true,
      gateway: gateway,
      profiles: profiles,
      local: LocalAccountStore(store: keyValue),
      firestore: FakeFirebaseFirestore(),
      appOpenInfo: () async =>
          (appVersion: '1.0.0', androidVersion: '14', deviceModel: 'SINTETIS'),
    );
    await services.auth.login(email: 'a@contoh.test', password: 'rahasia1');
  });

  tearDown(() async {
    await services.appOpen.dispose();
    await services.sessionActivity.dispose();
    await services.auth.dispose();
    audio.dispose();
    await session.dispose();
    location.dispose();
    await settings.dispose();
    await gateway.dispose();
  });

  group('penghentian audio narasi saat keluar akun (B20)', () {
    test('logout menghentikan audio narasi dan sesi aktif', () async {
      await session.start(SessionMode.explore);
      await audio.play(
        const AudioClip(poiId: 'P01', kind: AudioClipKind.narration),
      );
      expect(audio.current.status, PlaybackStatus.playing);
      expect(session.current.isActive, isTrue);

      await services.auth.logout();

      expect(audio.current.status, PlaybackStatus.idle);
      expect(session.current.isActive, isFalse);
    });

    test('hapus akun menghentikan audio narasi dan sesi aktif', () async {
      await session.start(SessionMode.explore);
      await audio.play(
        const AudioClip(poiId: 'P01', kind: AudioClipKind.narration),
      );
      expect(audio.current.status, PlaybackStatus.playing);

      await services.auth.deleteAccount(password: 'rahasia1');

      expect(audio.current.status, PlaybackStatus.idle);
      expect(session.current.isActive, isFalse);
    });

    test('keluar dari luar aplikasi menghentikan audio narasi walau tidak ada sesi lokasi aktif', () async {
      await audio.play(
        const AudioClip(poiId: 'P01', kind: AudioClipKind.narration),
      );
      expect(session.current.isActive, isFalse);
      expect(audio.current.status, PlaybackStatus.playing);

      gateway.externalSignOut();
      await pumpEventQueue();

      expect(audio.current.status, PlaybackStatus.idle);
    });

    test('keluar dari luar aplikasi menghentikan audio yang sedang dijeda (notifikasi media)', () async {
      await audio.play(
        const AudioClip(poiId: 'P01', kind: AudioClipKind.narration),
      );
      await audio.pause();
      expect(audio.current.status, PlaybackStatus.paused);

      gateway.externalSignOut();
      await pumpEventQueue();

      expect(audio.current.status, PlaybackStatus.idle);
    });
  });
}
