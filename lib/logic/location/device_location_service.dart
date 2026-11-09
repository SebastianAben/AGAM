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
  }) : _policy = policy ?? AdaptiveIntervalPolicy(),
       _visible = appVisible {
    _desiredInterval = _policy.normal;
    _controller = StreamController<LocationFix>.broadcast(
      onListen: _schedule,
      onCancel: _schedule,
    );
  }

  final PositionSource _source;
  final AdaptiveIntervalPolicy _policy;
  late final StreamController<LocationFix> _controller;
  final _issues = StreamController<LocationIssue>.broadcast();

  bool _visible;
  bool _session = false;
  bool _disposed = false;
  List<Poi> _pois = const [];
  late Duration _desiredInterval;

  StreamSubscription<LocationFix>? _subscription;
  LocationRequest? _active;
  LocationFix? _lastFix;
  Future<void> _queue = Future.value();
  AppLifecycleListener? _lifecycle;

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
  void attachToAppLifecycle() {
    _lifecycle ??= AppLifecycleListener(
      onStateChange: (state) => setAppVisible(
        state == AppLifecycleState.resumed ||
            state == AppLifecycleState.inactive,
      ),
    );
  }

  /// Dipanggil saat aplikasi tampil/tidak tampil di layar.
  Future<void> setAppVisible(bool visible) {
    _visible = visible;
    return _schedule();
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
    _lifecycle?.dispose();
    await _schedule();
    await _controller.close();
    await _issues.close();
  }

  /// Menyelaraskan langganan secara berurutan agar tidak ada dua langganan
  /// yang berjalan bersamaan.
  Future<void> _schedule() => _queue = _queue.then((_) => _reconcile());

  Future<void> _reconcile() async {
    final wanted =
        !_disposed && (_session || (_visible && _controller.hasListener));
    if (!wanted) {
      await _stop();
      return;
    }
    final request = LocationRequest(
      interval: _desiredInterval,
      sessionService: _session,
    );
    final active = _active;
    if (active == request) return;
    // Selama layar mati, jangan memulai ulang foreground service sesi hanya
    // untuk mengganti interval.
    if (active != null &&
        active.sessionService &&
        request.sessionService &&
        !_visible) {
      return;
    }
    await _subscription?.cancel();
    _active = request;
    _subscription = _source
        .watch(request)
        .listen(_onFix, onError: _onError, cancelOnError: false);
  }

  Future<void> _stop() async {
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
    _lastFix = fix;
    _controller.add(fix);
    final desired = _policy.evaluate(fix, _pois);
    if (desired != _desiredInterval) {
      _desiredInterval = desired;
      _schedule();
    }
  }

  void _onError(Object error) {
    final issue = error is LocationSourceException
        ? error.issue
        : LocationIssue.other;
    _issues.add(issue);
  }
}
