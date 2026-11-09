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
}
