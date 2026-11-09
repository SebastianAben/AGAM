/// Implementasi asli [VoiceGuidance] (PB12).
library;

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../contracts/contracts.dart';

/// Mesin TTS. Dipisah dari plugin agar logika dapat diuji.
abstract interface class TtsEngine {
  /// Apakah suara offline untuk [languageTag] terpasang di perangkat.
  Future<bool> isLanguageInstalled(String languageTag);

  Future<void> setLanguage(String languageTag);

  /// Membacakan [text], menggantikan ucapan yang sedang berjalan.
  Future<void> speak(String text);

  Future<void> stop();
}

class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _configured = false;

  @override
  Future<bool> isLanguageInstalled(String languageTag) async {
    try {
      return await _tts.isLanguageInstalled(languageTag) == true;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> setLanguage(String languageTag) async {
    await _tts.setLanguage(languageTag);
    if (!_configured) {
      // Arahan baru menggantikan arahan lama (QUEUE_FLUSH) dan tidak
      // menunggu ucapan selesai.
      await _tts.setQueueMode(0);
      await _tts.awaitSpeakCompletion(false);
      _configured = true;
    }
  }

  @override
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}

/// Membacakan arahan navigasi dengan mesin TTS Android, locale `id-ID`
/// (PRD §10). Hanya untuk arahan belokan; narasi, prompt, dan pengumuman
/// tiba memakai file audio.
///
/// Suara dianggap tersedia hanya jika suara `id-ID` **offline** terpasang.
/// Jika tidak, [speak] diam dan UI tetap menampilkan arahan visual
/// (PRD §19); UI dapat mengarahkan pengguna memasang data suara.
class DeviceVoiceGuidance implements VoiceGuidance {
  DeviceVoiceGuidance({TtsEngine? engine})
    : _engine = engine ?? FlutterTtsEngine();

  static const languageTag = 'id-ID';

  final TtsEngine _engine;
  Future<bool>? _available;

  /// Hasil pemeriksaan di-cache. Panggil [refreshAvailability] setelah
  /// pengguna memasang data suara.
  @override
  Future<bool> isAvailable() => _available ??= _check();

  void refreshAvailability() => _available = null;

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty || !await isAvailable()) return;
    await _engine.speak(text);
  }

  @override
  Future<void> stop() => _engine.stop();

  Future<bool> _check() async {
    final installed = await _engine.isLanguageInstalled(languageTag);
    if (installed) await _engine.setLanguage(languageTag);
    return installed;
  }
}
