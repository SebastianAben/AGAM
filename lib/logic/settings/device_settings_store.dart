/// Implementasi asli [SettingsStore].
library;

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../contracts/contracts.dart';

/// Penyimpanan kunci–nilai lokal. Dipisah dari plugin agar dapat diuji.
abstract interface class KeyValueStore {
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

class SharedPreferencesKeyValueStore implements KeyValueStore {
  SharedPreferencesKeyValueStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool?> getBool(String key) => _preferences.getBool(key);

  @override
  Future<void> setBool(String key, bool value) =>
      _preferences.setBool(key, value);

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// Menyimpan pengaturan di perangkat. Hanya pengaturan; posisi pengguna
/// tidak pernah disimpan (PRD A01).
///
/// Sebelum [switchAccount] pertama kali dipanggil, pengaturan memakai kunci
/// perangkat ([autoPlayNarrationKey]); jalur ini dipakai demo tanpa akun.
/// Setelah akun dipakai, pengaturan disimpan per `uid` (PRD §15.1): logout
/// hanya menyembunyikannya, login kembali memulihkannya, dan
/// [clearAccount] menghapusnya saat hapus akun.
class DeviceSettingsStore implements SettingsStore {
  DeviceSettingsStore({KeyValueStore? store})
    : _store = store ?? SharedPreferencesKeyValueStore();

  /// Kunci perangkat, dipakai sebelum ada akun (demo).
  static const autoPlayNarrationKey = 'settings.autoPlayNarration';

  /// Kunci pengaturan milik akun [uid].
  static String autoPlayNarrationKeyFor(String uid) =>
      'account.$uid.settings.autoPlayNarration';

  final KeyValueStore _store;
  final _controller = StreamController<AppSettings>.broadcast();
  AppSettings _current = const AppSettings();

  bool _accountScoped = false;
  String? _uid;

  @override
  AppSettings get current => _current;

  @override
  Stream<AppSettings> get settings => _controller.stream;

  /// Kunci untuk pengaturan aktif; `null` saat akun dipakai tetapi belum
  /// ada yang login, sehingga perubahan hanya disimpan di memori.
  String? get _key => _accountScoped
      ? (_uid == null ? null : autoPlayNarrationKeyFor(_uid!))
      : autoPlayNarrationKey;

  /// Membaca pengaturan tersimpan. Sebelum selesai, [current] berisi
  /// default. Pembacaan yang gagal mempertahankan default.
  Future<void> load() async {
    final key = _key;
    if (key == null) return;
    try {
      final autoPlay = await _store.getBool(key);
      if (autoPlay != null && key == _key) {
        _set(_current.copyWith(autoPlayNarration: autoPlay));
      }
    } on Exception {
      // Tetap memakai default.
    }
  }

  /// Berpindah ke pengaturan milik akun [uid], atau ke default saat
  /// [uid] `null` (logout). Pengaturan akun lain tidak terbaca.
  Future<void> switchAccount(String? uid) async {
    if (_accountScoped && uid == _uid) return;
    _accountScoped = true;
    _uid = uid;
    _set(const AppSettings());
    await load();
  }

  /// Menghapus pengaturan milik akun [uid] dari perangkat (hapus akun).
  Future<void> clearAccount(String uid) async {
    await _store.remove(autoPlayNarrationKeyFor(uid));
    if (_accountScoped && _uid == uid) _set(const AppSettings());
  }

  @override
  Future<void> update(AppSettings settings) async {
    _set(settings);
    final key = _key;
    if (key != null) {
      await _store.setBool(key, settings.autoPlayNarration);
    }
  }

  void _set(AppSettings settings) {
    _current = settings;
    _controller.add(settings);
  }

  Future<void> dispose() => _controller.close();
}
