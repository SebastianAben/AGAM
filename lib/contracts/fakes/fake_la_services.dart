/// Implementasi palsu layanan track LA. Tidak membaca GPS, tidak memutar
/// audio, dan tidak mengakses jaringan.
library;

import 'dart:async';

import '../models/audio.dart';
import '../models/content.dart';
import '../models/geo.dart';
import '../models/location.dart';
import '../models/session.dart';
import '../models/settings.dart';
import '../services/la_services.dart';
import 'fake_data.dart';

class FakePermissionService implements PermissionService {
  FakePermissionService({
    this.locationResult = LocationPermissionStatus.granted,
    this.notificationResult = NotificationPermissionStatus.granted,
  });

  /// Ubah nilai ini untuk mencoba tampilan izin ditolak atau perkiraan.
  LocationPermissionStatus locationResult;
  NotificationPermissionStatus notificationResult;

  LocationPermissionStatus _location = LocationPermissionStatus.denied;
  NotificationPermissionStatus _notification =
      NotificationPermissionStatus.denied;

  @override
  Future<LocationPermissionStatus> locationStatus() async => _location;

  @override
  Future<LocationPermissionStatus> requestLocation() async =>
      _location = locationResult;

  @override
  Future<NotificationPermissionStatus> notificationStatus() async =>
      _notification;

  @override
  Future<NotificationPermissionStatus> requestNotification() async =>
      _notification = notificationResult;

  @override
  Future<void> openAppSettings() async {}

  /// Ubah ke `false` untuk mencoba tampilan saat optimasi baterai sudah
  /// dinonaktifkan.
  bool batteryOptimized = true;

  @override
  Future<bool> isBatteryOptimized() async => batteryOptimized;

  @override
  Future<void> openBatteryOptimizationSettings() async =>
      batteryOptimized = false;
}

/// Mensimulasikan pengguna berjalan melewati [waypoints] secara berulang.
///
/// Jalur SINTETIS: garis lurus antar-POI, bukan jalan sesungguhnya.
/// Simulasi berjalan selama ada listener pada [positions].
class FakeLocationService implements LocationService {
  FakeLocationService({
    List<GeoPoint>? waypoints,
    this.tick = const Duration(seconds: 1),
    double stepM = 5,
    this.accuracyM = 5,
  }) : _path = _interpolate(
         waypoints ??
             [
               for (final id in fakeTrailOrder)
                 fakePois.firstWhere((p) => p.id == id).position,
             ],
         stepM,
       ) {
    _controller = StreamController<LocationFix>.broadcast(
      onListen: _startWalking,
      onCancel: _stopWalking,
    );
  }

  final Duration tick;
  final double accuracyM;
  final List<GeoPoint> _path;
  late final StreamController<LocationFix> _controller;
  Timer? _timer;
  int _index = 0;
  LocationFix? _lastFix;

  @override
  Stream<LocationFix> get positions => _controller.stream;

  @override
  LocationFix? get lastFix => _lastFix;

  void _startWalking() {
    _timer = Timer.periodic(tick, (_) {
      final fix = LocationFix(
        position: _path[_index],
        accuracyM: accuracyM,
        timestamp: DateTime.now(),
      );
      _index = (_index + 1) % _path.length;
      _lastFix = fix;
      _controller.add(fix);
    });
  }

  void _stopWalking() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _stopWalking();
    _controller.close();
  }

  static List<GeoPoint> _interpolate(List<GeoPoint> waypoints, double stepM) {
    final path = <GeoPoint>[];
    for (var i = 0; i < waypoints.length - 1; i++) {
      final a = waypoints[i];
      final b = waypoints[i + 1];
      final steps = (a.distanceTo(b) / stepM).ceil().clamp(1, 100000);
      for (var s = 0; s < steps; s++) {
        final t = s / steps;
        path.add(
          GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t),
        );
      }
    }
    path.add(waypoints.last);
    return path;
  }
}

class FakePoiRepository implements PoiRepository {
  FakePoiRepository({List<Poi>? pois, List<Facility>? facilities})
    : _pois = List.unmodifiable(pois ?? fakePois),
      _facilities = List.unmodifiable(facilities ?? fakeFacilities);

  final List<Poi> _pois;
  final List<Facility> _facilities;

  @override
  Stream<List<Poi>> watchPois() => Stream.value(_pois);

  @override
  Stream<List<Facility>> watchFacilities() => Stream.value(_facilities);

  @override
  Future<Poi?> poiById(String id) async {
    for (final poi in _pois) {
      if (poi.id == id) return poi;
    }
    return null;
  }

  @override
  Future<ContentSource> refresh() async => ContentSource.bundled;
}

/// Memancarkan trigger saat posisi dari [location] masuk radius POI.
///
/// Disederhanakan: tanpa dwell, cooldown, histeresis, maupun foreground
/// service. Setiap POI hanya terpicu sekali per sesi.
class FakeSessionController implements SessionController {
  FakeSessionController({required this._location, List<Poi>? pois})
    : _pois = pois ?? fakePois;

  final LocationService _location;
  final List<Poi> _pois;
  final _stateController = StreamController<SessionState>.broadcast();
  final _triggerController = StreamController<PoiTriggerEvent>.broadcast();
  final _triggered = <String>{};
  StreamSubscription<LocationFix>? _subscription;
  SessionState _current = const SessionState.idle();

  @override
  SessionState get current => _current;

  @override
  Stream<SessionState> get state => _stateController.stream;

  @override
  Stream<PoiTriggerEvent> get triggers => _triggerController.stream;

  @override
  Future<void> start(SessionMode mode) async {
    if (mode == SessionMode.none) {
      throw ArgumentError.value(
        mode,
        'mode',
        'Gunakan end() untuk mengakhiri sesi',
      );
    }
    if (!_current.isActive) _triggered.clear();
    _setState(
      SessionState(mode: mode, startedAt: _current.startedAt ?? DateTime.now()),
    );
    _subscription ??= _location.positions.listen(_onFix);
  }

  @override
  Future<void> end() async {
    await _subscription?.cancel();
    _subscription = null;
    _setState(
      const SessionState.idle(lastEndReason: SessionEndReason.userEnded),
    );
  }

  void _onFix(LocationFix fix) {
    if (!fix.isAccurateForTrigger) return;
    for (final poi in _pois) {
      if (_triggered.contains(poi.id)) continue;
      if (fix.position.distanceTo(poi.position) > poi.radiusM) continue;
      _triggered.add(poi.id);
      _triggerController.add(
        PoiTriggerEvent(
          poiId: poi.id,
          mode: _current.mode,
          response: _current.mode == SessionMode.navigation
              ? TriggerResponse.brief
              : TriggerResponse.full,
          triggeredAt: fix.timestamp,
        ),
      );
    }
  }

  void _setState(SessionState state) {
    _current = state;
    _stateController.add(state);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _stateController.close();
    await _triggerController.close();
  }
}

/// Mensimulasikan pemutaran tanpa suara. Durasi klip SINTETIS.
class FakeAudioService implements AudioService {
  FakeAudioService({this.tick = const Duration(seconds: 1)});

  final Duration tick;
  final _controller = StreamController<PlaybackState>.broadcast();
  PlaybackState _current = const PlaybackState.idle();
  Timer? _timer;

  static const _durations = {
    AudioClipKind.narration: Duration(seconds: 60),
    AudioClipKind.prompt: Duration(seconds: 4),
    AudioClipKind.arrival: Duration(seconds: 3),
  };

  @override
  PlaybackState get current => _current;

  @override
  Stream<PlaybackState> get state => _controller.stream;

  @override
  Future<void> play(AudioClip clip) async {
    _run(clip, Duration.zero);
  }

  @override
  Future<void> pause() async {
    if (_current.status != PlaybackStatus.playing) return;
    _timer?.cancel();
    _emit(_with(PlaybackStatus.paused, _current.position));
  }

  @override
  Future<void> resume() async {
    final clip = _current.clip;
    if (_current.status != PlaybackStatus.paused || clip == null) return;
    _run(clip, _current.position);
  }

  @override
  Future<void> replay() async {
    final clip = _current.clip;
    if (clip != null) _run(clip, Duration.zero);
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _emit(const PlaybackState.idle());
  }

  void _run(AudioClip clip, Duration from) {
    _timer?.cancel();
    final duration = _durations[clip.kind]!;
    var position = from;
    _emit(
      PlaybackState(
        status: PlaybackStatus.playing,
        clip: clip,
        position: position,
        duration: duration,
      ),
    );
    _timer = Timer.periodic(tick, (timer) {
      position += const Duration(seconds: 1);
      if (position >= duration) {
        timer.cancel();
        _emit(_with(PlaybackStatus.completed, duration));
      } else {
        _emit(_with(PlaybackStatus.playing, position));
      }
    });
  }

  PlaybackState _with(PlaybackStatus status, Duration position) =>
      PlaybackState(
        status: status,
        clip: _current.clip,
        position: position,
        duration: _current.duration,
      );

  void _emit(PlaybackState state) {
    _current = state;
    _controller.add(state);
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

/// Mencatat teks yang "dibacakan" ke [spoken] tanpa mengeluarkan suara.
class FakeVoiceGuidance implements VoiceGuidance {
  FakeVoiceGuidance({this.available = true});

  /// Ubah ke `false` untuk mencoba tampilan saat suara TTS tidak tersedia.
  bool available;

  final List<String> spoken = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> speak(String text) async {
    if (available) spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

class FakeSettingsStore implements SettingsStore {
  final _controller = StreamController<AppSettings>.broadcast();
  AppSettings _current = const AppSettings();

  @override
  AppSettings get current => _current;

  @override
  Stream<AppSettings> get settings => _controller.stream;

  @override
  Future<void> update(AppSettings settings) async {
    _current = settings;
    _controller.add(settings);
  }
}
