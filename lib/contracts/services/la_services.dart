/// Antarmuka layanan milik track LA (lokasi, sesi, data, audio, akun).
///
/// Implementasi asli berada di
/// `lib/logic/{location,session,data,audio,settings,account}/`.
/// Implementasi palsu berada di `lib/contracts/fakes/`.
library;

import '../models/account.dart';
import '../models/activity.dart';
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

/// Akun Firebase Auth email + password (PB21). Kontrak v1.1.
///
/// Implementasi asli mencatat event `signUp`, `login`, dan `logout` lewat
/// [ActivityLogger]; pemanggil tidak perlu mencatatnya. Password tidak
/// pernah disimpan, dicatat, atau ditulis ke log debug.
///
/// Kegagalan dilempar sebagai `AuthException`.
abstract interface class AuthService {
  AuthState get current;

  /// Langsung memancarkan keadaan terkini, lalu setiap perubahan. Sesi login
  /// bertahan setelah aplikasi ditutup.
  Stream<AuthState> get state;

  /// Membuat akun dan profil `users/{uid}`. UI wajib memastikan pengguna
  /// sudah menyetujui pemberitahuan privasi sebelum memanggil (PRD §16).
  /// Tanpa verifikasi email.
  Future<UserAccount> signUp({
    required String email,
    required String password,
    required UserRole role,
  });

  Future<UserAccount> login({required String email, required String password});

  /// Kembali ke keadaan belum login. Progres lokal milik akun tidak dihapus,
  /// hanya disembunyikan (PRD §15.1). Mengakhiri sesi aktif dilakukan
  /// perangkaian layanan LA yang mendengarkan [state], bukan UI.
  Future<void> logout();

  /// Mengirim email reset password dari Firebase Auth. Tidak melempar error
  /// untuk email yang tidak terdaftar agar keberadaan akun tidak terungkap.
  Future<void> sendPasswordReset({required String email});

  /// Menghapus profil `users/{uid}`, seluruh log milik akun, data lokal milik
  /// akun, lalu akun Firebase Auth (PRD §16). [password] dipakai untuk
  /// autentikasi ulang yang disyaratkan Firebase sebelum hapus akun.
  Future<void> deleteAccount({required String password});
}

/// Log aktivitas internal ke Firestore `activity_logs` (PB22). Kontrak v1.1.
abstract interface class ActivityLogger {
  /// Mencatat [event] untuk akun yang sedang login, beserta `uid`, `type`,
  /// dan waktu sesuai `ActivityEvent.timePrecision`. Saat offline event
  /// diantrekan dan terkirim saat online.
  ///
  /// Tidak pernah melempar error dan tidak perlu ditunggu. Event diabaikan
  /// jika tidak ada akun yang login.
  void log(ActivityEvent event);
}
