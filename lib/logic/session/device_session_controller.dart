/// Implementasi asli [SessionController] (PB06).
library;

import 'dart:async';

import '../../contracts/contracts.dart';
import '../location/device_location_service.dart';
import '../location/geofence_engine.dart';
import '../location/position_source.dart';

/// Mengatur sesi Explore/Navigasi/Trail (PRD §6) dan memancarkan trigger POI
/// dari [GeofenceEngine].
///
/// - [start] memulai pembacaan lokasi sesi (foreground service tipe
///   `location`). Mengganti mode saat sesi aktif tidak menghentikan service.
/// - [end] menghentikan pembacaan lokasi dan foreground service.
/// - Sesi berakhir otomatis setelah pengguna berada di luar area kampus
///   selama [kOutsideCampusAutoEnd], atau saat izin lokasi dicabut.
/// - Di luar area kampus, trigger tidak aktif (PRD §9.3).
///
/// Respons trigger: Navigasi → [TriggerResponse.brief] (notifikasi ringkas
/// tanpa audio); Explore/Trail → [TriggerResponse.full]. Efek samping
/// (notifikasi, getar, audio) dijalankan `TriggerResponder`, bukan kelas ini.
///
/// Status area kampus hanya diperbarui dari pembacaan dengan akurasi
/// ≤20 m agar pembacaan buruk tidak memulai hitungan auto-end.
///
/// Engine geofence dipertahankan antar-sesi sehingga cooldown 10 menit per
/// POI tetap berlaku jika pengguna mengakhiri lalu memulai sesi baru.
class DeviceSessionController implements SessionController {
  DeviceSessionController({
    required this._location,
    required PoiRepository pois,
    required this._isInsideCampus,
    DateTime Function()? clock,
    GeofenceEngine Function(List<Poi> pois)? engineFactory,
  }) : _poiRepository = pois,
       _clock = clock ?? DateTime.now,
       _engineFactory = engineFactory ?? ((pois) => GeofenceEngine(pois: pois));

  final DeviceLocationService _location;
  final PoiRepository _poiRepository;
  final bool Function(GeoPoint point) _isInsideCampus;
  final DateTime Function() _clock;
  final GeofenceEngine Function(List<Poi> pois) _engineFactory;

  final _stateController = StreamController<SessionState>.broadcast();
  final _triggerController = StreamController<PoiTriggerEvent>.broadcast();

  SessionState _current = const SessionState.idle();
  GeofenceEngine? _engine;
  StreamSubscription<List<Poi>>? _poiSubscription;
  StreamSubscription<LocationFix>? _fixSubscription;
  StreamSubscription<LocationIssue>? _issueSubscription;
  Timer? _outsideTimer;
  bool _insideCampus = true;

  @override
  SessionState get current => _current;

  @override
  Stream<SessionState> get state => _stateController.stream;

  @override
  Stream<PoiTriggerEvent> get triggers => _triggerController.stream;

  /// Apakah pembacaan terakhir yang akurat berada di dalam area kampus.
  /// `true` sampai ada pembacaan yang membuktikan sebaliknya.
  bool get isInsideCampus => _insideCampus;

  @override
  Future<void> start(SessionMode mode) async {
    if (mode == SessionMode.none) {
      throw ArgumentError.value(
        mode,
        'mode',
        'Gunakan end() untuk mengakhiri sesi',
      );
    }
    if (_current.isActive) {
      if (_current.mode != mode) {
        _setState(SessionState(mode: mode, startedAt: _current.startedAt));
      }
      return;
    }

    _poiSubscription ??= _poiRepository.watchPois().listen(_onPois);
    _insideCampus = true;
    _setState(SessionState(mode: mode, startedAt: _clock()));
    _issueSubscription = _location.issues.listen(_onIssue);
    _fixSubscription = _location.positions.listen(_onFix);
    await _location.beginSession();
  }

  @override
  Future<void> end() => _end(SessionEndReason.userEnded);

  Future<void> dispose() async {
    if (_current.isActive) await _end(SessionEndReason.userEnded);
    await _poiSubscription?.cancel();
    await _stateController.close();
    await _triggerController.close();
  }

  Future<void> _end(SessionEndReason reason) async {
    if (!_current.isActive) return;
    _outsideTimer?.cancel();
    _outsideTimer = null;
    _engine?.suspend();
    final fixes = _fixSubscription;
    final issues = _issueSubscription;
    _fixSubscription = null;
    _issueSubscription = null;
    _setState(SessionState.idle(lastEndReason: reason));
    await fixes?.cancel();
    await issues?.cancel();
    await _location.endSession();
  }

  void _onPois(List<Poi> pois) {
    _location.setPois(pois);
    final engine = _engine;
    try {
      if (engine == null) {
        _engine = _engineFactory(pois);
      } else {
        engine.updatePois(pois);
      }
    } on ArgumentError {
      // Data sudah divalidasi PoiRepository; jika tetap ditolak engine,
      // snapshot sebelumnya dipakai.
    }
  }

  void _onFix(LocationFix fix) {
    if (!_current.isActive) return;
    if (fix.isAccurateForTrigger) _updateCampusState(fix);
    if (!_current.isActive) return;

    final engine = _engine;
    if (engine == null) return;
    final entries = engine.evaluate(fix, enabled: _insideCampus);
    final mode = _current.mode;
    for (final entry in entries) {
      _triggerController.add(
        PoiTriggerEvent(
          poiId: entry.poiId,
          mode: mode,
          response: mode == SessionMode.navigation
              ? TriggerResponse.brief
              : TriggerResponse.full,
          triggeredAt: entry.triggeredAt,
        ),
      );
    }
  }

  void _updateCampusState(LocationFix fix) {
    final inside = _isInsideCampus(fix.position);
    if (inside == _insideCampus) return;
    _insideCampus = inside;
    if (inside) {
      _outsideTimer?.cancel();
      _outsideTimer = null;
    } else {
      _outsideTimer = Timer(
        kOutsideCampusAutoEnd,
        () => _end(SessionEndReason.outsideCampusTimeout),
      );
    }
  }

  void _onIssue(LocationIssue issue) {
    if (issue == LocationIssue.permissionDenied) {
      _end(SessionEndReason.permissionRevoked);
    }
  }

  void _setState(SessionState state) {
    _current = state;
    _stateController.add(state);
  }
}
