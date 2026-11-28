import 'dart:async';

import 'package:agam/logic/audio/device_voice_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEngine implements TtsEngine {
  bool installed = true;
  List<Map<String, String>> voices = const [];
  bool acceptVoice = true;
  bool throwOnCheck = false;
  Completer<void>? checkGate;
  int checks = 0;
  int voiceQueries = 0;
  final languages = <String>[];
  final selectedVoices = <Map<String, String>>[];
  final spoken = <String>[];
  int stops = 0;

  @override
  Future<bool> isLanguageInstalled(String languageTag) async {
    checks++;
    await checkGate?.future;
    if (throwOnCheck) throw StateError('TTS belum siap');
    return installed;
  }

  @override
  Future<List<Map<String, String>>> getVoices() async {
    voiceQueries++;
    await checkGate?.future;
    if (throwOnCheck) throw StateError('TTS belum siap');
    return voices;
  }

  @override
  Future<void> setLanguage(String languageTag) async =>
      languages.add(languageTag);

  @override
  Future<bool> setVoice(Map<String, String> voice) async {
    selectedVoices.add(voice);
    return acceptVoice;
  }

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

  test(
    'fallback isLanguageInstalled saat getVoices kosong: id-ID terpasang',
    () async {
      expect(await voice.isAvailable(), isTrue);
      expect(engine.languages, ['id-ID']);
      expect(engine.selectedVoices, isEmpty);
    },
  );

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

  test(
    'memilih suara offline Indonesia terbaik dan tidak pernah jatuh ke en-US',
    () async {
      engine.voices = const [
        {
          'name': 'en-us-x-sfg-local',
          'locale': 'en-US',
          'quality': 'very high',
          'network_required': '0',
        },
        {
          'name': 'id-id-x-idc-network',
          'locale': 'id-ID',
          'quality': 'very high',
          'network_required': '1',
        },
        {
          'name': 'id-id-x-dfz-local',
          'locale': 'id-ID',
          'quality': 'very high',
          'network_required': '0',
          'features': 'networkTimeoutMs\tnotInstalled',
        },
        {
          'name': 'id-ID-language',
          'locale': 'id-ID',
          'quality': 'high',
          'network_required': '0',
        },
        {
          'name': 'id-id-x-idc-local',
          'locale': 'id-ID',
          'quality': 'normal',
          'network_required': '0',
        },
        {
          'name': 'id-id-x-ide-local',
          'locale': 'id-ID',
          'quality': 'high',
          'network_required': '0',
        },
      ];

      expect(await voice.isAvailable(), isTrue);
      expect(engine.languages, ['id-ID']);
      expect(engine.selectedVoices, [
        {'name': 'id-id-x-ide-local', 'locale': 'id-ID'},
      ]);
      expect(engine.checks, 0);
    },
  );

  test('menerima locale in-ID / id_ID offline yang terpasang', () async {
    engine.voices = const [
      {
        'name': 'in-id-offline-voice',
        'locale': 'in_ID',
        'quality': 'normal',
        'network_required': 'false',
      },
    ];

    expect(await voice.isAvailable(), isTrue);
    expect(engine.languages, ['id-ID']);
    expect(engine.selectedVoices, [
      {'name': 'in-id-offline-voice', 'locale': 'in_ID'},
    ]);
  });

  test('hanya suara en-US atau suara id-ID online/notInstalled → tidak tersedia (diam)', () async {
    engine.installed = true;
    engine.voices = const [
      {
        'name': 'en-us-x-sfg-local',
        'locale': 'en-US',
        'quality': 'high',
        'network_required': '0',
      },
      {
        'name': 'id-id-x-idc-network',
        'locale': 'id-ID',
        'quality': 'high',
        'network_required': '1',
      },
      {
        'name': 'id-id-x-ide-local',
        'locale': 'id-ID',
        'quality': 'high',
        'network_required': '0',
        'features': 'notInstalled',
      },
    ];

    expect(await voice.isAvailable(), isFalse);
    await voice.speak('Belok kiri');
    expect(engine.spoken, isEmpty);
    expect(engine.languages, isEmpty);
    expect(engine.selectedVoices, isEmpty);
  });

  test('setVoice gagal → mengembalikan false dan tidak berbicara', () async {
    engine.acceptVoice = false;
    engine.voices = const [
      {
        'name': 'id-id-x-idc-local',
        'locale': 'id-ID',
        'quality': 'normal',
        'network_required': '0',
      },
    ];

    expect(await voice.isAvailable(), isFalse);
    await voice.speak('Belok kanan');
    expect(engine.spoken, isEmpty);
  });

  test('hasil positif di-cache sampai refreshAvailability dipanggil', () async {
    engine.installed = true;
    expect(await voice.isAvailable(), isTrue);
    expect(await voice.isAvailable(), isTrue);
    expect(engine.checks, 1);

    voice.refreshAvailability();
    expect(await voice.isAvailable(), isTrue);
    expect(engine.checks, 2);
  });

  test(
    'hasil false tidak di-cache permanen: mendeteksi suara yang baru dipasang',
    () async {
      engine.installed = false;
      expect(await voice.isAvailable(), isFalse);
      expect(engine.checks, 1);

      // Pengguna memasang data suara Indonesia tanpa restart aplikasi.
      engine.installed = true;
      expect(await voice.isAvailable(), isTrue);
      expect(engine.checks, 2);

      // Setelah berhasil tersedia, hasil positif di-cache.
      expect(await voice.isAvailable(), isTrue);
      expect(engine.checks, 2);
    },
  );

  test('galat saat pemeriksaan tidak membekukan cache permanen', () async {
    engine.throwOnCheck = true;
    await expectLater(voice.isAvailable(), throwsStateError);

    engine.throwOnCheck = false;
    engine.installed = true;
    expect(await voice.isAvailable(), isTrue);
  });

  test('pemanggilan isAvailable paralel berbagi satu pemeriksaan', () async {
    engine.checkGate = Completer<void>();
    final first = voice.isAvailable();
    final second = voice.isAvailable();
    engine.checkGate!.complete();
    expect(await Future.wait([first, second]), [true, true]);
    expect(engine.voiceQueries, 1);
  });

  test('stop meneruskan ke mesin TTS', () async {
    await voice.stop();
    expect(engine.stops, 1);
  });
}
