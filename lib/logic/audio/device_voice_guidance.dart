/// Implementasi asli [VoiceGuidance] (PB12).
library;

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../contracts/contracts.dart';

/// Mesin TTS. Dipisah dari plugin agar logika dapat diuji.
abstract interface class TtsEngine {
  /// Apakah suara offline untuk [languageTag] terpasang di perangkat.
  Future<bool> isLanguageInstalled(String languageTag);

  /// Daftar suara yang diekspos mesin TTS (tiap entri berisi mis. `name`,
  /// `locale`, `quality`, `network_required`, `features`). Mengembalikan daftar
  /// kosong bila mesin tidak mendukung atau gagal mengambil daftar suara.
  Future<List<Map<String, String>>> getVoices();

  Future<void> setLanguage(String languageTag);

  /// Memilih suara eksplisit (`name` dan `locale`). Mengembalikan `true` bila
  /// mesin TTS menerima pilihan suara tersebut.
  Future<bool> setVoice(Map<String, String> voice);

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
  Future<List<Map<String, String>>> getVoices() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return const [];
      final voices = <Map<String, String>>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final normalized = <String, String>{};
        item.forEach((key, value) {
          if (key != null && value != null) {
            normalized[key.toString()] = value.toString();
          }
        });
        if (normalized.isNotEmpty) {
          voices.add(normalized);
        }
      }
      return voices;
    } on PlatformException {
      return const [];
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
  Future<bool> setVoice(Map<String, String> voice) async {
    try {
      final result = await _tts.setVoice(voice);
      return result == 1 || result == true;
    } on PlatformException {
      return false;
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
/// (PRD §10): arahan belokan dan pengumuman tiba di fasilitas. Narasi,
/// prompt, dan pengumuman tiba di POI memakai file audio.
///
/// Suara dianggap tersedia hanya jika suara Bahasa Indonesia (`id-ID` /
/// `in-ID`) **offline** terpasang dan berhasil dipilih secara eksplisit,
/// sehingga mesin TTS tidak pernah jatuh ke aksen `en-US` untuk membaca teks
/// Indonesia. Jika tidak tersedia, [speak] diam dan UI tetap menampilkan
/// arahan visual (PRD §19); UI dapat mengarahkan pengguna memasang data suara.
class DeviceVoiceGuidance implements VoiceGuidance {
  DeviceVoiceGuidance({TtsEngine? engine})
    : _engine = engine ?? FlutterTtsEngine();

  static const languageTag = 'id-ID';

  final TtsEngine _engine;
  Future<bool>? _available;

  /// Hasil positif (`true`) di-cache sampai [refreshAvailability] dipanggil.
  /// Hasil `false` atau galat tidak di-cache permanen agar pemanggilan
  /// berikutnya dapat mendeteksi data suara yang baru dipasang atau mesin TTS
  /// yang baru siap.
  @override
  Future<bool> isAvailable() {
    final cached = _available;
    if (cached != null) return cached;
    late final Future<bool> check;
    check = _check().then(
      (available) {
        if (!available && identical(_available, check)) {
          _available = null;
        }
        return available;
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_available, check)) {
          _available = null;
        }
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    _available = check;
    return check;
  }

  void refreshAvailability() => _available = null;

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty || !await isAvailable()) return;
    await _engine.speak(text);
  }

  @override
  Future<void> stop() => _engine.stop();

  Future<bool> _check() async {
    final voices = await _engine.getVoices();
    if (voices.isNotEmpty) {
      final candidates = voices.where(_isOfflineIndonesianVoice).toList()
        ..sort(_compareVoices);
      if (candidates.isEmpty) return false;
      await _engine.setLanguage(languageTag);
      for (final candidate in candidates) {
        final selected = await _engine.setVoice({
          'name': candidate['name']!,
          'locale': candidate['locale']!,
        });
        if (selected) return true;
      }
      return false;
    }

    // Fallback bila mesin tidak mengekspor daftar suara (platform lama atau
    // fake minimal pada test).
    final installed = await _engine.isLanguageInstalled(languageTag);
    if (installed) await _engine.setLanguage(languageTag);
    return installed;
  }

  static bool _isOfflineIndonesianVoice(Map<String, String> voice) {
    final name = voice['name']?.trim();
    final locale = voice['locale']?.trim();
    if (name == null || name.isEmpty || locale == null || locale.isEmpty) {
      return false;
    }
    final normalizedLocale = locale.toLowerCase().replaceAll('_', '-');
    if (normalizedLocale != 'id-id' && normalizedLocale != 'in-id') {
      return false;
    }
    final networkRequired = voice['network_required']?.trim().toLowerCase();
    if (networkRequired == '1' || networkRequired == 'true') {
      return false;
    }
    final features = voice['features'];
    if (features != null && features.toLowerCase().contains('notinstalled')) {
      return false;
    }
    return true;
  }

  static int _compareVoices(Map<String, String> a, Map<String, String> b) {
    final preferredDiff =
        (_isPreferredLocalIdVoice(b) ? 1 : 0) -
        (_isPreferredLocalIdVoice(a) ? 1 : 0);
    if (preferredDiff != 0) return preferredDiff;

    final qualityDiff = _qualityRank(b['quality']) - _qualityRank(a['quality']);
    if (qualityDiff != 0) return qualityDiff;

    final localeDiff =
        (_isIdIdLocale(b['locale']) ? 1 : 0) -
        (_isIdIdLocale(a['locale']) ? 1 : 0);
    if (localeDiff != 0) return localeDiff;

    final nameDiff = (a['name'] ?? '').compareTo(b['name'] ?? '');
    if (nameDiff != 0) return nameDiff;

    return (a['locale'] ?? '').compareTo(b['locale'] ?? '');
  }

  static bool _isPreferredLocalIdVoice(Map<String, String> voice) {
    final name = (voice['name'] ?? '').toLowerCase();
    final hasLocal = name.contains('local');
    final isGoogleOrIdId = name.startsWith('id-id') || name.contains('google');
    return hasLocal && isGoogleOrIdId;
  }

  static bool _isIdIdLocale(String? locale) {
    final normalized = locale?.trim().toLowerCase().replaceAll('_', '-');
    return normalized == 'id-id';
  }

  static int _qualityRank(String? quality) =>
      switch (quality?.trim().toLowerCase()) {
        'very high' => 5,
        'high' => 4,
        'normal' => 3,
        'low' => 2,
        'very low' => 1,
        _ => 0,
      };
}
