import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/settings/device_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements KeyValueStore {
  final values = <String, bool>{};
  bool failRead = false;

  @override
  Future<bool?> getBool(String key) async {
    if (failRead) throw Exception('rusak');
    return values[key];
  }

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> setString(String key, String value) async {}

  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  test('default auto-play mati sebelum dan tanpa data tersimpan', () async {
    final store = DeviceSettingsStore(store: _MemoryStore());
    expect(store.current.autoPlayNarration, isFalse);
    await store.load();
    expect(store.current.autoPlayNarration, isFalse);
  });

  test(
    'update disimpan dan dibaca kembali setelah aplikasi dibuka ulang',
    () async {
      final memory = _MemoryStore();
      final first = DeviceSettingsStore(store: memory);
      final emitted = <AppSettings>[];
      final sub = first.settings.listen(emitted.add);
      await first.update(const AppSettings(autoPlayNarration: true));
      await pumpEventQueue();
      expect(emitted.single.autoPlayNarration, isTrue);
      await sub.cancel();

      final reopened = DeviceSettingsStore(store: memory);
      await reopened.load();
      expect(reopened.current.autoPlayNarration, isTrue);
    },
  );

  test('pembacaan gagal mempertahankan default', () async {
    final store = DeviceSettingsStore(store: _MemoryStore()..failRead = true);
    await store.load();
    expect(store.current.autoPlayNarration, isFalse);
  });

  test('hanya kunci pengaturan yang disimpan', () async {
    final memory = _MemoryStore();
    await DeviceSettingsStore(store: memory)
        .update(const AppSettings(autoPlayNarration: true));
    expect(memory.values.keys, [DeviceSettingsStore.autoPlayNarrationKey]);
  });

  group('per akun (PRD §15.1)', () {
    const on = AppSettings(autoPlayNarration: true);

    test(
      'akun lain di perangkat yang sama tidak melihat pengaturan akun pertama',
      () async {
        final memory = _MemoryStore();
        final store = DeviceSettingsStore(store: memory);
        await store.switchAccount('uid-a');
        await store.update(on);

        await store.switchAccount('uid-b');
        expect(store.current.autoPlayNarration, isFalse);
      },
    );

    test('logout menyembunyikan, login kembali memulihkan', () async {
      final memory = _MemoryStore();
      final store = DeviceSettingsStore(store: memory);
      await store.switchAccount('uid-a');
      await store.update(on);

      await store.switchAccount(null);
      expect(store.current.autoPlayNarration, isFalse);
      await store.switchAccount('uid-a');
      expect(store.current.autoPlayNarration, isTrue);
    });

    test(
      'tanpa akun yang login, perubahan tidak disimpan ke perangkat',
      () async {
        final memory = _MemoryStore();
        final store = DeviceSettingsStore(store: memory);
        await store.switchAccount(null);
        await store.update(on);
        expect(memory.values, isEmpty);
      },
    );

    test('hapus akun menghapus pengaturan milik akun itu saja', () async {
      final memory = _MemoryStore();
      final store = DeviceSettingsStore(store: memory);
      await store.switchAccount('uid-b');
      await store.update(on);
      await store.switchAccount('uid-a');
      await store.update(on);

      await store.clearAccount('uid-a');
      expect(store.current.autoPlayNarration, isFalse);
      expect(memory.values.keys, [
        DeviceSettingsStore.autoPlayNarrationKeyFor('uid-b'),
      ]);
    });
  });
}
