/// Implementasi asli [AuthService]: Firebase Auth email + password dan
/// profil `users/{uid}` (PB21; PRD §15.1, §15.4, §16).
library;

import 'dart:async';

import '../../contracts/contracts.dart';
import 'auth_gateway.dart';
import 'profile_store.dart';

/// Akun AGAM di perangkat.
///
/// - Event `signUp`, `login`, dan `logout` dicatat di sini lewat
///   [ActivityLogger], setelah keadaan login diperbarui agar log membawa
///   `uid` yang benar (logout dicatat sebelum keluar).
/// - Sesi login dipulihkan saat cold start lewat [restore]; role dibaca dari
///   salinan lokal sehingga aplikasi tetap berjalan tanpa jaringan.
/// - Saat logout: [beforeSignOut] (perangkaian LA mengakhiri sesi aktif),
///   catat `logout`, lalu [flushLogs] agar log terkirim selagi masih login.
/// - Hapus akun: autentikasi ulang, [beforeDelete], log milik akun, profil,
///   data lokal ([clearLocalData]), lalu akun Firebase Auth.
class DeviceAuthService implements AuthService {
  DeviceAuthService({
    required this._gateway,
    required this._profiles,
    required this._local,
    required this._activity,
    this._beforeSignOut,
    this._flushLogs,
    this._beforeDelete,
    this._deleteRemoteLogs,
    this._clearLocalData,
  });

  final AuthGateway _gateway;
  final ProfileStore _profiles;
  final LocalAccountStore _local;
  final ActivityLogger _activity;
  final Future<void> Function()? _beforeSignOut;
  final Future<void> Function()? _flushLogs;
  final Future<void> Function()? _beforeDelete;
  final Future<void> Function(String uid)? _deleteRemoteLogs;
  final Future<void> Function(String uid)? _clearLocalData;

  final _controller = StreamController<AuthState>.broadcast();
  AuthState _current = const AuthState.signedOut();
  StreamSubscription<AuthUser?>? _userSubscription;

  @override
  AuthState get current => _current;

  @override
  Stream<AuthState> get state => Stream.multi((listener) {
    listener.add(_current);
    final subscription = _controller.stream.listen(listener.add);
    listener.onCancel = subscription.cancel;
  });

  /// Memulihkan sesi login yang tersimpan Firebase Auth, lalu mengikuti
  /// perubahan dari luar (mis. akun dinonaktifkan). Dipanggil sekali saat
  /// cold start, sebelum layar pertama.
  Future<void> restore() async {
    final user = _gateway.currentUser;
    if (user != null) {
      final role = await _local.readRole(user.uid) ?? await _tryReadRole(user);
      if (role == null) {
        // Role tidak diketahui (data lokal hilang dan tanpa jaringan, atau
        // profil tidak ada): kembali ke layar login.
        await _safeSignOut();
      } else {
        _emit(AuthState.signedIn(_account(user, role)));
      }
    }
    _userSubscription ??= _gateway.userChanges.listen((user) {
      if (user == null && _current.isSignedIn) {
        _emit(const AuthState.signedOut());
      }
    });
  }

  @override
  Future<UserAccount> signUp({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final user = await _gateway.createUser(email: email, password: password);
    try {
      await _profiles.create(uid: user.uid, role: role);
    } on AuthException {
      // Akun tanpa profil tidak dapat dipakai; batalkan agar email dapat
      // didaftarkan ulang.
      await _gateway.deleteCurrentUser().catchError((_) {});
      await _safeSignOut();
      rethrow;
    }
    await _local.saveRole(user.uid, role);
    final account = _account(user, role);
    _emit(AuthState.signedIn(account));
    _activity.log(ActivityEvent.signUp(role: role));
    return account;
  }

  @override
  Future<UserAccount> login({
    required String email,
    required String password,
  }) async {
    final user = await _gateway.signIn(email: email, password: password);
    UserRole? role;
    try {
      role = await _profiles.read(user.uid);
    } on AuthException {
      await _safeSignOut();
      rethrow;
    }
    if (role == null) {
      final localRole = await _local.readRole(user.uid);
      if (localRole == null) {
        await _safeSignOut();
        throw const AuthException(AuthErrorCode.unknown);
      }
      // Profil Firestore hilang (mis. penghapusan akun sebelumnya gagal di
      // tengah jalan saat offline), tetapi salinan role lokal masih tersedia:
      // coba pulihkan profil di Firestore dan tetap izinkan masuk.
      try {
        await _profiles.create(uid: user.uid, role: localRole);
      } on AuthException {
        // Tetap lanjutkan masuk memakai role lokal agar akun tidak terkunci.
      }
      role = localRole;
    }
    await _local.saveRole(user.uid, role);
    final account = _account(user, role);
    _emit(AuthState.signedIn(account));
    _activity.log(const ActivityEvent.login());
    return account;
  }

  @override
  Future<void> logout() async {
    if (!_current.isSignedIn) return;
    await _beforeSignOut?.call();
    // Dicatat sebelum keluar karena log membutuhkan akun yang login.
    _activity.log(const ActivityEvent.logout());
    await _flushLogs?.call();
    await _gateway.signOut();
    _emit(const AuthState.signedOut());
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _gateway.sendPasswordReset(email: email);
    } on AuthException catch (e) {
      // Email tidak terdaftar tidak diungkap (kontrak AuthService).
      if (e.code != AuthErrorCode.wrongCredentials) rethrow;
    }
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final account = _current.account;
    if (account == null) return;
    final uid = account.uid;
    final role = account.role;
    await _gateway.reauthenticate(password: password);
    await _beforeDelete?.call();
    await _deleteRemoteLogs?.call(uid);
    await _profiles.delete(uid);
    try {
      await _gateway.deleteCurrentUser();
    } on Object {
      // Akun Firebase Auth masih ada: coba pulihkan profil di Firestore agar
      // email tidak terkunci permanen dan pengguna dapat mencoba ulang.
      try {
        await _profiles.create(uid: uid, role: role);
      } on Object {
        // Best-effort; salinan role lokal tetap dipertahankan hingga akun Auth
        // benar-benar terhapus.
      }
      rethrow;
    }
    try {
      await _local.clear(uid);
      await _clearLocalData?.call(uid);
    } finally {
      if (_current.isSignedIn) _emit(const AuthState.signedOut());
    }
  }

  Future<void> dispose() async {
    await _userSubscription?.cancel();
    await _controller.close();
  }

  Future<UserRole?> _tryReadRole(AuthUser user) async {
    try {
      final role = await _profiles
          .read(user.uid)
          .timeout(const Duration(seconds: 5));
      if (role != null) await _local.saveRole(user.uid, role);
      return role;
    } on AuthException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  Future<void> _safeSignOut() async {
    try {
      await _gateway.signOut();
    } on AuthException {
      // Keluar lokal tetap dianggap berhasil.
    }
  }

  void _emit(AuthState state) {
    _current = state;
    _controller.add(state);
  }

  static UserAccount _account(AuthUser user, UserRole role) =>
      UserAccount(uid: user.uid, email: user.email, role: role);
}
