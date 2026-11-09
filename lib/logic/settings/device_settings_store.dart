/// Implementasi asli [SettingsStore].
library;

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../contracts/contracts.dart';

/// Penyimpanan kunci–nilai lokal. Dipisah dari plugin agar dapat diuji.
abstract interface class KeyValueStore {
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
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
}

/// Menyimpan pengaturan di perangkat. Hanya pengaturan; posisi pengguna
/// tidak pernah disimpan (PRD A01).
class DeviceSettingsStore implements SettingsStore {
  DeviceSettingsStore({KeyValueStore? store})
    : _store = store ?? SharedPreferencesKeyValueStore();

  static const autoPlayNarrationKey = 'settings.autoPlayNarration';

  final KeyValueStore _store;
  final _controller = StreamController<AppSettings>.broadcast();
  AppSettings _current = const AppSettings();

  @override
  AppSettings get current => _current;

  @override
  Stream<AppSettings> get settings => _controller.stream;

  /// Membaca pengaturan tersimpan. Sebelum selesai, [current] berisi
  /// default. Pembacaan yang gagal mempertahankan default.
  Future<void> load() async {
    try {
      final autoPlay = await _store.getBool(autoPlayNarrationKey);
      if (autoPlay != null) {
        _set(_current.copyWith(autoPlayNarration: autoPlay));
      }
    } on Exception {
      // Tetap memakai default.
    }
  }

  @override
  Future<void> update(AppSettings settings) async {
    _set(settings);
    await _store.setBool(autoPlayNarrationKey, settings.autoPlayNarration);
  }

  void _set(AppSettings settings) {
    _current = settings;
    _controller.add(settings);
  }

  Future<void> dispose() => _controller.close();
}
