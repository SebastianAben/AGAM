/// Akun pengguna (PRD §6, §15.1, §16; PB21). Kontrak v1.1.
library;

/// Role yang dipilih sendiri saat daftar. Tidak diverifikasi dan tidak
/// membedakan fitur; hanya label statistik tim (PRD §3).
///
/// Nama enum dipakai apa adanya di Firestore `users/{uid}.role` dan log
/// `signUp.role`.
enum UserRole { mahasiswaItb, pengunjung }

class UserAccount {
  const UserAccount({
    required this.uid,
    required this.email,
    required this.role,
  });

  /// ID Firebase Auth. Dipakai sebagai bagian kunci penyimpanan lokal per
  /// akun (progres trail, POI dikunjungi, pengaturan).
  final String uid;
  final String email;
  final UserRole role;
}

/// Keadaan login. Tanpa login, seluruh mode tidak tersedia (PRD §6).
class AuthState {
  const AuthState.signedOut() : account = null;

  const AuthState.signedIn(UserAccount this.account);

  final UserAccount? account;

  bool get isSignedIn => account != null;
}

/// Penyebab kegagalan operasi akun, untuk dipetakan UI ke pesan Bahasa
/// Indonesia.
enum AuthErrorCode {
  invalidEmail,

  /// Password terlalu pendek atau lemah menurut Firebase Auth.
  weakPassword,

  emailAlreadyInUse,

  /// Email atau password salah. Sengaja tidak dibedakan agar keberadaan
  /// akun tidak terungkap.
  wrongCredentials,

  /// Tidak ada koneksi, mis. saat login pertama (PB21: pesan offline).
  network,

  tooManyRequests,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.code);

  final AuthErrorCode code;

  @override
  String toString() => 'AuthException(${code.name})';
}
