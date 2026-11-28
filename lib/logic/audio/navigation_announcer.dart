/// Arahan suara navigasi dan pengumuman tiba (PB12, F04, F06).
library;

import 'dart:async';

import '../../contracts/contracts.dart';

/// Mendengarkan [NavigationState] dari `NavigationController` (LB) dan:
///
/// - membacakan teks arahan setiap kali langkah berganti atau rute baru
///   dihitung (mis. setelah rerouting), lewat [VoiceGuidance];
/// - saat status berubah menjadi tiba, menghentikan TTS lalu memutar file
///   audio pengumuman tiba milik POI tujuan lewat [AudioService];
/// - tiba di fasilitas (tanpa file audio tiba) diumumkan dengan TTS:
///   "Anda telah tiba di {nama fasilitas}" (PRD §10, keputusan 24 November
///   2026). Jika suara `id-ID` tidak tersedia, pengumuman tidak dibacakan dan
///   kartu tiba di UI menjadi penggantinya.
///
/// Langkah dengan manuver `arrive` tidak dibacakan karena pengumuman tiba
/// memakai file audio atau kalimat tiba di atas. Setiap kedatangan diumumkan
/// sekali, walau status tiba dipancarkan berulang.
class NavigationAnnouncer {
  NavigationAnnouncer({
    required this._navigation,
    required this._voice,
    required this._audio,
  });

  final NavigationController _navigation;
  final VoiceGuidance _voice;
  final AudioService _audio;

  StreamSubscription<NavigationState>? _subscription;
  NavigationStatus _lastStatus = NavigationStatus.idle;
  WalkingRoute? _lastRoute;
  int? _lastStepIndex;
  String? _arrivedAt;
  int _generation = 0;
  bool _disposed = false;
  Future<void> _queue = Future<void>.value();

  void start() {
    _disposed = false;
    _subscription ??= _navigation.state.listen(_onState);
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onState(NavigationState state) {
    final previous = _lastStatus;
    switch (state.status) {
      case NavigationStatus.idle:
      case NavigationStatus.error:
        _lastStatus = state.status;
        _forgetStep();
        if (previous == state.status) return;
        _generation++;
        _enqueue(_stopVoice);
      case NavigationStatus.calculating:
      case NavigationStatus.rerouting:
      case NavigationStatus.offRoute:
        _lastStatus = state.status;
        if (previous == NavigationStatus.onRoute ||
            previous == NavigationStatus.arrived) {
          _generation++;
        }
      case NavigationStatus.onRoute:
        _lastStatus = state.status;
        final route = state.route;
        final index = state.currentStepIndex;
        final step = state.currentStep;
        if (route == null || index == null || step == null) return;
        if (identical(route, _lastRoute) && index == _lastStepIndex) return;
        _lastRoute = route;
        _lastStepIndex = index;
        if (step.maneuver == Maneuver.arrive) {
          _generation++;
          return;
        }
        final generation = ++_generation;
        _enqueue(() => _announceStep(step.instruction, generation));
      case NavigationStatus.arrived:
        final sameArrival =
            previous == NavigationStatus.arrived &&
            state.target?.id == _arrivedAt;
        _lastStatus = state.status;
        _arrivedAt = state.target?.id;
        if (sameArrival) return;
        _forgetStep();
        final target = state.target;
        final generation = ++_generation;
        _enqueue(() => _handleArrival(target, generation));
    }
  }

  void _enqueue(Future<void> Function() task) {
    _queue = _queue.catchError((Object _, StackTrace _) {}).then((_) => task());
  }

  Future<void> _stopVoice() async {
    if (_disposed) return;
    await _voice.stop();
  }

  Future<void> _handleArrival(NavigationTarget? target, int generation) async {
    if (_disposed || generation != _generation) return;
    await _voice.stop();
    if (_disposed || generation != _generation || target == null) return;
    switch (target.kind) {
      case NavigationTargetKind.poi:
        await _audio.play(
          AudioClip(poiId: target.id, kind: AudioClipKind.arrival),
        );
      case NavigationTargetKind.facility:
        await _announceFacilityArrival(target, generation);
    }
  }

  Future<void> _announceFacilityArrival(
    NavigationTarget target,
    int generation,
  ) async {
    if (!await _voice.isAvailable()) return;
    // Navigation may have ended while availability was checked; speaking
    // after the user closed the arrival card would be out of place.
    if (_disposed ||
        generation != _generation ||
        _lastStatus != NavigationStatus.arrived) {
      return;
    }
    await _voice.speak(arrivalSentence(target.name));
  }

  /// Kalimat pengumuman tiba di fasilitas (PRD §10).
  static String arrivalSentence(String name) => 'Anda telah tiba di $name';

  Future<void> _announceStep(String instruction, int generation) async {
    if (_disposed || generation != _generation) return;
    if (_isBlockingAudioPlaying()) return;
    if (!await _voice.isAvailable()) return;
    if (_disposed || generation != _generation) return;
    if (_isBlockingAudioPlaying()) return;
    await _voice.speak(instruction);
  }

  bool _isBlockingAudioPlaying() {
    final playback = _audio.current;
    if (playback.status != PlaybackStatus.playing) return false;
    final kind = playback.clip?.kind;
    return kind == AudioClipKind.prompt || kind == AudioClipKind.arrival;
  }

  void _forgetStep() {
    _lastRoute = null;
    _lastStepIndex = null;
  }
}
