/// Pembungkus Firebase Auth (PB21). Dipisah dari plugin agar alur akun dapat
/// diuji tanpa Firebase.
library;

import 'package:firebase_auth/firebase_auth.dart';

import '../../contracts/contracts.dart';

/// Pengguna Firebase Auth yang sedang login.
class AuthUser {
  const AuthUser({required this.uid, required this.email});

  final String uid;
  final String email;
}

/// Operasi Firebase Auth yang dipakai AGAM. Kegagalan dilempar sebagai
/// [AuthException]; password tidak pernah disimpan atau dicatat.
abstract interface class AuthGateway {
  AuthUser? get currentUser;

  /// Berubah saat login, logout, atau akun dihapus/dinonaktifkan.
  Stream<AuthUser?> get userChanges;

  Future<AuthUser> createUser({
    required String email,
    required String password,
  });

  Future<AuthUser> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> sendPasswordReset({required String email});

  /// Autentikasi ulang pengguna saat ini, disyaratkan sebelum hapus akun.
  Future<void> reauthenticate({required String password});

  Future<void> deleteCurrentUser();
}

/// Memetakan kode `FirebaseAuthException` ke [AuthErrorCode].
///
/// Email atau password salah tidak dibedakan agar keberadaan akun tidak
/// terungkap; Firebase dengan email enumeration protection juga hanya
/// mengirim `invalid-credential`.
AuthErrorCode authErrorCodeFor(String code) => switch (code) {
  'invalid-email' => AuthErrorCode.invalidEmail,
  'weak-password' => AuthErrorCode.weakPassword,
  'email-already-in-use' => AuthErrorCode.emailAlreadyInUse,
  'invalid-credential' ||
  'invalid-login-credentials' ||
  'wrong-password' ||
  'user-not-found' ||
  'user-mismatch' ||
  'user-disabled' => AuthErrorCode.wrongCredentials,
  'network-request-failed' => AuthErrorCode.network,
  'too-many-requests' => AuthErrorCode.tooManyRequests,
  _ => AuthErrorCode.unknown,
};

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  AuthUser? get currentUser => _toUser(_auth.currentUser);

  @override
  Stream<AuthUser?> get userChanges => _auth.authStateChanges().map(_toUser);

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) => _guard(() async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _requireUser(credential.user);
  });

  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      _guard(() async {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return _requireUser(credential.user);
      });

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<void> sendPasswordReset({required String email}) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> reauthenticate({required String password}) => _guard(() async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthException(AuthErrorCode.wrongCredentials);
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  });

  @override
  Future<void> deleteCurrentUser() => _guard(() async {
    await _auth.currentUser?.delete();
  });

  static AuthUser? _toUser(User? user) {
    final email = user?.email;
    if (user == null || email == null) return null;
    return AuthUser(uid: user.uid, email: email);
  }

  static AuthUser _requireUser(User? user) {
    final result = _toUser(user);
    if (result == null) throw const AuthException(AuthErrorCode.unknown);
    return result;
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(authErrorCodeFor(e.code));
    }
  }
}
