/// Antarmuka layanan milik track LA (lokasi, sesi, data, audio).
///
/// Implementasi asli berada di `lib/logic/{location,session,data,audio,settings}/`.
/// Implementasi palsu berada di `lib/contracts/fakes/`.
library;

import '../models/audio.dart';
import '../models/content.dart';
import '../models/location.dart';
import '../models/session.dart';
import '../models/settings.dart';

abstract interface class PermissionService {
  Future<LocationPermissionStatus> locationStatus();

  /// Meminta izin lokasi akurat "saat aplikasi digunakan". Dilarang meminta
  /// izin lokasi "sepanjang waktu".
  Future<LocationPermissionStatus> requestLocation();

  Future<NotificationPermissionStatus> notificationStatus();
  Future<NotificationPermissionStatus> requestNotification();

  /// Membuka halaman pengaturan aplikasi di sistem.
  Future<void> openAppSettings();

  /// Apakah optimasi baterai sistem masih membatasi aplikasi. Jika `true`,
  /// trigger saat layar mati dapat berhenti; onboarding menampilkan panduan.
  Future<bool> isBatteryOptimized();

  /// Membuka pengaturan optimasi baterai agar pengguna memilih
  /// "Tanpa batasan" untuk AGAM.
  Future<void> openBatteryOptimizationSettings();
}

abstract interface class LocationService {
  /// Posisi pengguna.
  ///
  /// Memancarkan data hanya saat aplikasi tampil di layar (mode peta biasa)
  /// atau selama sesi aktif. Di luar kondisi itu aliran diam dan tidak ada
  /// pembacaan lokasi. Pengaturan ini ditangani implementasi, bukan UI.
  Stream<LocationFix> get positions;

  /// Posisi terakhir yang masih ada di memori, jika ada.
  LocationFix? get lastFix;
}

abstract interface class PoiRepository {
  /// Daftar POI terkini. Langsung memancarkan salinan yang tersedia, lalu
  /// memancarkan ulang setiap kali data diperbarui dari Firestore.
  Stream<List<Poi>> watchPois();

  Stream<List<Facility>> watchFacilities();

  Future<Poi?> poiById(String id);

  /// Mencoba mengambil data terbaru dari Firestore. Tidak pernah melempar
  /// error karena jaringan; mengembalikan sumber data yang akhirnya dipakai.
  Future<ContentSource> refresh();
}

abstract interface class SessionController {
  SessionState get current;
  Stream<SessionState> get state;

  /// Trigger POI selama sesi aktif.
  Stream<PoiTriggerEvent> get triggers;

  /// Memulai sesi dengan [mode] (bukan [SessionMode.none]). Jika sesi lain
  /// sedang aktif, mode diganti tanpa mengakhiri foreground service.
  Future<void> start(SessionMode mode);

  /// Tombol "Akhiri": menghentikan pembacaan lokasi dan foreground service.
  Future<void> end();
}

abstract interface class AudioService {
  PlaybackState get current;
  Stream<PlaybackState> get state;

  /// Memutar [clip], menghentikan klip yang sedang diputar.
  Future<void> play(AudioClip clip);

  Future<void> pause();
  Future<void> resume();

  /// Memutar ulang klip terakhir dari awal.
  Future<void> replay();

  Future<void> stop();
}

abstract interface class VoiceGuidance {
  /// Apakah suara TTS Bahasa Indonesia tersedia di perangkat. Jika `false`,
  /// UI tetap menampilkan arahan secara visual.
  Future<bool> isAvailable();

  Future<void> speak(String text);
  Future<void> stop();
}

abstract interface class SettingsStore {
  AppSettings get current;
  Stream<AppSettings> get settings;
  Future<void> update(AppSettings settings);
}
