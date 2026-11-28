/// Implementasi asli [LocationService] (PB02) sekaligus pengatur pembacaan
/// lokasi selama sesi (PB06).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../contracts/contracts.dart';
import 'adaptive_interval.dart';
import 'position_source.dart';

/// Membaca lokasi hanya pada kondisi yang diizinkan PRD §6:
///
/// - **Peta biasa:** saat aplikasi tampil di layar dan ada pendengar
///   [positions]. Berhenti saat aplikasi diminimalkan, ditutup, atau layar
///   mati.
/// - **Sesi:** antara [beginSession] dan [endSession], memakai foreground
///   service sehingga tetap berjalan saat layar mati.
///
/// Di luar kedua kondisi itu tidak ada langganan ke [PositionSource].
/// Posisi hanya disimpan sebagai [lastFix] selama pembacaan berjalan dan
/// dihapus saat pembacaan berhenti; tidak ada riwayat (PRD A01).
///
/// Interval adaptif ([AdaptiveIntervalPolicy]) hanya diterapkan saat aplikasi
/// tampil. Mengganti interval berarti membatalkan dan memulai ulang
/// langganan, yang pada geolocator juga memulai ulang foreground service;
/// memulai foreground service dari latar belakang dapat ditolak Android 12+.
/// Selama layar mati, interval terakhir dipertahankan.
class DeviceLocationService implements LocationService {
  DeviceLocationService({
    required this._source,
    AdaptiveIntervalPolicy? policy,
    bool appVisible = true,
    Stream<bool>? serviceStatus,
    Duration Function(int attempt)? retryDelay,
  }) : _policy = policy ?? AdaptiveIntervalPolicy(),
       _visible = appVisible,
       _retryDelay = retryDelay ?? _defaultRetryDelay {
    _desiredInterval = _policy.normal;
    _controller = StreamController<LocationFix>.broadcast(
      onListen: _schedule,
      onCancel: _schedule,
    );
    _serviceStatusSubscription = serviceStatus?.listen(_onServiceStatus);
  }

  static Duration _defaultRetryDelay(int attempt) {
    final seconds = 1 << attempt.clamp(1, 5);
    return Duration(seconds: seconds > 30 ? 30 : seconds);
  }

  final PositionSource _source;
  final AdaptiveIntervalPolicy _policy;
  final Duration Function(int attempt) _retryDelay;
  late final StreamController<LocationFix> _controller;
  final _issues = StreamController<LocationIssue>.broadcast();

  bool _visible;
  bool _session = false;
  bool _disposed = false;
  bool _allowBackgroundNormalReset = false;
  List<Poi> _pois = const [];
  late Duration _desiredInterval;

  StreamSubscription<LocationFix>? _subscription;
  LocationRequest? _active;
  LocationFix? _lastFix;
  Future<void> _queue = Future.value();
  AppLifecycleListener? _lifecycle;
  StreamSubscription<bool>? _serviceStatusSubscription;
  LocationIssue? _lastIssue;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  @override
  Stream<LocationFix> get positions => _controller.stream;

  @override
  LocationFix? get lastFix => _lastFix;

  /// Masalah pembacaan lokasi (izin dicabut, layanan lokasi mati).
  Stream<LocationIssue> get issues => _issues.stream;

  /// Parameter langganan yang sedang berjalan, atau `null` jika tidak ada
  /// pembacaan lokasi.
  LocationRequest? get activeRequest => _active;

  bool get isSessionActive => _session;
  bool get isAppVisible => _visible;

  /// Menghubungkan visibilitas ke siklus hidup aplikasi Flutter. Aplikasi
  /// dianggap tampil pada `resumed` dan `inactive` (mis. dialog izin atau
  /// panel notifikasi menutupi layar sesaat).
  ///
  /// Saat transisi ke `inactive` ketika sesi aktif memakai interval lambat,
  /// interval dikembalikan ke normal selagi masih di latar depan agar dwell
  /// latar belakang tidak terhenti pada interval 10 detik.
  void attachToAppLifecycle() {
    _lifecycle ??= AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.inactive &&
            _session &&
            (_desiredInterval != _policy.normal ||
                (_active != null && _active!.interval != _policy.normal))) {
          _desiredInterval = _policy.normal;
          _policy.reset();
          unawaited(_schedule());
        }
        unawaited(
          setAppVisible(
            state == AppLifecycleState.resumed ||
                state == AppLifecycleState.inactive,
          ),
        );
      },
    );
  }

  /// Dipanggil saat aplikasi tampil/tidak tampil di layar.
  Future<void> setAppVisible(bool visible) {
    final leavingForeground = _visible && !visible;
    _visible = visible;
    if (leavingForeground &&
        _session &&
        (_desiredInterval != _policy.normal ||
            (_active != null && _active!.interval != _policy.normal))) {
      _desiredInterval = _policy.normal;
      _policy.reset();
      _allowBackgroundNormalReset = true;
    } else if (visible) {
      _allowBackgroundNormalReset = false;
    }
    if (visible && _lastIssue == LocationIssue.serviceDisabled) {
      return _restartAfterServiceEnabled();
    }
    return _schedule();
  }

  void _onServiceStatus(bool enabled) {
    if (_disposed) return;
    if (!enabled) {
      _lastFix = null;
      _lastIssue = LocationIssue.serviceDisabled;
      _issues.add(LocationIssue.serviceDisabled);
    } else if (_visible && _lastIssue == LocationIssue.serviceDisabled) {
      unawaited(_restartAfterServiceEnabled());
    }
  }

  Future<void> _restartAfterServiceEnabled() {
    _lastIssue = null;
    return _queue = _queue.then((_) async {
      // Android membatasi start foreground service dari background. Pulihkan
      // hanya saat aplikasi tampil; resume akan menyelaraskan kembali sesi.
      if (_disposed || !_visible) return;
      await _stop();
      await _reconcile();
    });
  }

  /// POI untuk interval adaptif. Dipanggil lapisan sesi saat dataset berubah.
  void setPois(Iterable<Poi> pois) => _pois = List.unmodifiable(pois);

  /// Memulai pembacaan lokasi sesi dengan foreground service.
  Future<void> beginSession() {
    _session = true;
    return _schedule();
  }

  /// Menghentikan pembacaan lokasi sesi. Jika aplikasi tampil dan peta
  /// masih mendengarkan, pembacaan berlanjut sebagai mode peta biasa tanpa
  /// foreground service.
  Future<void> endSession() {
    _session = false;
    return _schedule();
  }

  Future<void> dispose() async {
    _disposed = true;
    _cancelRetry();
    _lifecycle?.dispose();
    await _serviceStatusSubscription?.cancel();
    await _schedule();
    await _controller.close();
    await _issues.close();
  }

  /// Menyelaraskan langganan secara berurutan agar tidak ada dua langganan
  /// yang berjalan bersamaan.
  Future<void> _schedule() => _queue = _queue.then((_) => _reconcile());

  Future<void> _reconcile() async {
    final resetToNormal = _allowBackgroundNormalReset && !_visible && _session;
    _allowBackgroundNormalReset = false;
    final wanted =
        !_disposed && (_session || (_visible && _controller.hasListener));
    if (!wanted) {
      await _stop();
      return;
    }
    final request = LocationRequest(
      interval: resetToNormal ? _policy.normal : _desiredInterval,
      sessionService: _session,
    );
    final active = _active;
    if (active == request) return;
    // Selama layar mati, jangan memulai ulang foreground service sesi hanya
    // untuk mengganti interval, kecuali saat menurunkan interval lambat ke
    // normal ketika aplikasi baru beralih ke latar belakang.
    if (active != null &&
        active.sessionService &&
        request.sessionService &&
        !_visible &&
        !resetToNormal) {
      return;
    }
    _cancelRetry();
    final previous = _subscription;
    _subscription = null;
    await previous?.cancel();
    if (_disposed || !(_session || (_visible && _controller.hasListener))) {
      await _stop();
      return;
    }
    _active = request;
    _subscription = _source
        .watch(request)
        .listen(
          _onFix,
          onError: _onError,
          onDone: _onDone,
          cancelOnError: false,
        );
  }

  Future<void> _stop() async {
    _cancelRetry();
    _retryAttempt = 0;
    _allowBackgroundNormalReset = false;
    final subscription = _subscription;
    _subscription = null;
    _active = null;
    _lastFix = null;
    _policy.reset();
    _desiredInterval = _policy.normal;
    await subscription?.cancel();
  }

  void _onFix(LocationFix fix) {
    if (_subscription == null) return;
    _cancelRetry();
    _retryAttempt = 0;
    _lastIssue = null;
    _lastFix = fix;
    _controller.add(fix);
    final desired = _policy.evaluate(fix, _pois);
    if (desired != _desiredInterval) {
      _desiredInterval = desired;
      _schedule();
    }
  }

  void _onError(Object error) {
    _lastFix = null;
    final issue = error is LocationSourceException
        ? error.issue
        : LocationIssue.other;
    _lastIssue = issue;
    _issues.add(issue);
  }

  void _onDone() {
    // Stream native yang sudah berakhir bukan permintaan aktif. Saat kembali
    // dari pengaturan GPS/izin, reconcile wajib membuka langganan baru.
    _subscription = null;
    _active = null;
    _lastFix = null;
    final wanted =
        !_disposed && (_session || (_visible && _controller.hasListener));
    if (!wanted) return;
    if (_lastIssue == LocationIssue.permissionDenied ||
        _lastIssue == LocationIssue.serviceDisabled) {
      return;
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _cancelRetry();
    _retryAttempt++;
    _retryTimer = Timer(_retryDelay(_retryAttempt), () {
      _retryTimer = null;
      if (_disposed) return;
      unawaited(_schedule());
    });
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}
