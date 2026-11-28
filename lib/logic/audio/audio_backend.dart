/// Pemutar audio tingkat rendah untuk `DeviceAudioService` (PB08).
library;

import 'package:flutter/foundation.dart';

enum BackendPhase { idle, loading, ready, completed }

/// Keadaan pemutar pada satu waktu.
@immutable
class BackendSnapshot {
  const BackendSnapshot({
    required this.phase,
    required this.playing,
    this.position = Duration.zero,
    this.duration,
  });

  const BackendSnapshot.idle()
    : phase = BackendPhase.idle,
      playing = false,
      position = Duration.zero,
      duration = null;

  final BackendPhase phase;
  final bool playing;
  final Duration position;
  final Duration? duration;
}

/// Gagal memuat atau memutar file audio.
class AudioBackendException implements Exception {
  const AudioBackendException(this.message);

  final String message;

  @override
  String toString() => 'AudioBackendException($message)';
}

/// Dipisah dari plugin agar logika `DeviceAudioService` dapat diuji.
abstract interface class AudioBackend {
  Stream<BackendSnapshot> get snapshots;

  /// Memuat file audio dari aset APK. Judul ditampilkan di notifikasi dan
  /// lock screen. Melempar [AudioBackendException] jika aset tidak dapat
  /// dimuat.
  Future<Duration?> load(
    String assetPath, {
    required String title,
    required String subtitle,
  });

  /// Mulai/lanjutkan pemutaran. Tidak menunggu klip selesai.
  Future<void> play();

  Future<void> pause();
  Future<void> seek(Duration position);

  /// Menghentikan pemutaran dan menutup notifikasi media.
  Future<void> stop();
}
