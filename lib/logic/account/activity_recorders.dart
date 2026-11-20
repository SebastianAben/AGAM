/// Event log dari sesi dan cold start (PB22; PRD §15.5).
library;

import 'dart:async';

import '../../contracts/contracts.dart';

/// Mencatat `modeStart` dan `modeEnd` dari perubahan [SessionController].
///
/// Hanya tanggal dan mode; tanpa alasan berakhir (auto-end mengungkap
/// pengguna keluar kampus). Ganti mode tanpa mengakhiri sesi dicatat sebagai
/// akhir mode lama lalu awal mode baru.
class SessionActivityRecorder {
  SessionActivityRecorder({
    required this._session,
    required this._activity,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SessionController _session;
  final ActivityLogger _activity;
  final DateTime Function() _clock;

  StreamSubscription<SessionState>? _subscription;
  ActivityMode? _mode;
  DateTime? _since;

  void start() {
    _subscription ??= _session.state.listen(_onState);
  }

  /// Mencatat akhir mode yang sedang berjalan sekarang juga. Dipanggil
  /// sebelum logout, karena event sesi berakhir baru tiba setelah akun
  /// keluar dan log tanpa akun diabaikan.
  void closeOpenMode() => _switchTo(null);

  /// Melupakan mode berjalan tanpa mencatatnya. Dipanggil sebelum hapus
  /// akun agar tidak ada log baru setelah log milik akun dihapus.
  void discardOpenMode() {
    _mode = null;
    _since = null;
  }

  Future<void> dispose() async => _subscription?.cancel();

  void _onState(SessionState state) =>
      _switchTo(state.isActive ? ActivityMode.fromSession(state.mode) : null);

  void _switchTo(ActivityMode? mode) {
    if (mode == _mode) return;
    final now = _clock();
    final previous = _mode;
    final since = _since;
    if (previous != null && since != null) {
      _activity.log(
        ActivityEvent.modeEnd(mode: previous, duration: now.difference(since)),
      );
    }
    _mode = mode;
    _since = mode == null ? null : now;
    if (mode != null) _activity.log(ActivityEvent.modeStart(mode: mode));
  }
}

/// Informasi perangkat untuk event `appOpen`.
typedef AppOpenInfo = ({
  String appVersion,
  String androidVersion,
  String deviceModel,
});

/// Mencatat `appOpen` sekali per cold start.
///
/// Jika belum ada akun yang login saat aplikasi dibuka, dicatat begitu akun
/// pertama login pada proses yang sama. Tidak dicatat bila aplikasi dibuka
/// dari notifikasi trigger, agar waktu trigger tidak terekam (PRD §15.5).
class AppOpenRecorder {
  AppOpenRecorder({
    required this._auth,
    required this._activity,
    required this._info,
    required this._launchedFromNotification,
  });

  final AuthService _auth;
  final ActivityLogger _activity;
  final Future<AppOpenInfo> Function() _info;
  final Future<bool> Function() _launchedFromNotification;

  StreamSubscription<AuthState>? _subscription;
  bool _done = false;

  Future<void> start() async {
    if (await _launchedFromNotification()) {
      _done = true;
      return;
    }
    _subscription = _auth.state.listen((state) {
      if (state.isSignedIn) unawaited(_record());
    });
  }

  Future<void> _record() async {
    if (_done) return;
    _done = true;
    await _subscription?.cancel();
    final info = await _info();
    _activity.log(
      ActivityEvent.appOpen(
        appVersion: info.appVersion,
        androidVersion: info.androidVersion,
        deviceModel: info.deviceModel,
      ),
    );
  }

  Future<void> dispose() async => _subscription?.cancel();
}

/// Nilai field `appOpen` dibatasi 1–64 karakter (`firestore.rules`).
String shortField(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'unknown';
  return trimmed.length <= 64 ? trimmed : trimmed.substring(0, 64);
}
