import 'package:agam/logic/audio/device_voice_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEngine implements TtsEngine {
  bool installed = true;
  int checks = 0;
  final languages = <String>[];
  final spoken = <String>[];
  int stops = 0;

  @override
  Future<bool> isLanguageInstalled(String languageTag) async {
    checks++;
    return installed;
  }

  @override
  Future<void> setLanguage(String languageTag) async =>
      languages.add(languageTag);

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stops++;
}

void main() {
  late _FakeEngine engine;
  late DeviceVoiceGuidance voice;

  setUp(() {
    engine = _FakeEngine();
    voice = DeviceVoiceGuidance(engine: engine);
  });

  test('suara id-ID terpasang: tersedia dan bahasa diatur ke id-ID', () async {
    expect(await voice.isAvailable(), isTrue);
    expect(engine.languages, ['id-ID']);
  });

  test('membacakan arahan saat suara tersedia', () async {
    await voice.speak('Belok kiri');
    expect(engine.spoken, ['Belok kiri']);
  });

  test('suara tidak terpasang: diam, UI memakai arahan visual', () async {
    engine.installed = false;
    expect(await voice.isAvailable(), isFalse);
    await voice.speak('Belok kiri');
    expect(engine.spoken, isEmpty);
    expect(engine.languages, isEmpty);
  });

  test('teks kosong tidak dibacakan', () async {
    await voice.speak('   ');
    expect(engine.spoken, isEmpty);
  });

  test('ketersediaan di-cache dan dapat diperiksa ulang', () async {
    engine.installed = false;
    await voice.isAvailable();
    await voice.isAvailable();
    expect(engine.checks, 1);

    // Pengguna memasang data suara lalu aplikasi memeriksa ulang.
    engine.installed = true;
    voice.refreshAvailability();
    expect(await voice.isAvailable(), isTrue);
    expect(engine.checks, 2);
  });

  test('stop meneruskan ke mesin TTS', () async {
    await voice.stop();
    expect(engine.stops, 1);
  });
}
