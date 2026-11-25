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

  void start() {
    _subscription ??= _navigation.state.listen(_onState);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _onState(NavigationState state) async {
    final previous = _lastStatus;
    _lastStatus = state.status;

    switch (state.status) {
      case NavigationStatus.idle:
      case NavigationStatus.error:
        _forgetStep();
        if (previous != state.status) await _voice.stop();
      case NavigationStatus.calculating:
      case NavigationStatus.rerouting:
      case NavigationStatus.offRoute:
        break;
      case NavigationStatus.onRoute:
        await _announceStep(state);
      case NavigationStatus.arrived:
        final sameArrival =
            previous == NavigationStatus.arrived &&
            state.target?.id == _arrivedAt;
        _arrivedAt = state.target?.id;
        if (sameArrival) return;
        _forgetStep();
        await _voice.stop();
        final target = state.target;
        if (target == null) return;
        switch (target.kind) {
          case NavigationTargetKind.poi:
            await _audio.play(
              AudioClip(poiId: target.id, kind: AudioClipKind.arrival),
            );
          case NavigationTargetKind.facility:
            await _announceFacilityArrival(target);
        }
    }
  }

  Future<void> _announceFacilityArrival(NavigationTarget target) async {
    if (!await _voice.isAvailable()) return;
    // Navigation may have ended while availability was checked; speaking
    // after the user closed the arrival card would be out of place.
    if (_lastStatus != NavigationStatus.arrived) return;
    await _voice.speak(arrivalSentence(target.name));
  }

  /// Kalimat pengumuman tiba di fasilitas (PRD §10).
  static String arrivalSentence(String name) => 'Anda telah tiba di $name';

  Future<void> _announceStep(NavigationState state) async {
    final route = state.route;
    final index = state.currentStepIndex;
    final step = state.currentStep;
    if (route == null || index == null || step == null) return;
    if (identical(route, _lastRoute) && index == _lastStepIndex) return;
    _lastRoute = route;
    _lastStepIndex = index;
    if (step.maneuver == Maneuver.arrive) return;
    await _voice.speak(step.instruction);
  }

  void _forgetStep() {
    _lastRoute = null;
    _lastStepIndex = null;
  }
}
