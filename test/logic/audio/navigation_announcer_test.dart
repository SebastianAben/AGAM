import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/contracts/fakes/fake_lb_services.dart';
import 'package:agam/logic/audio/navigation_announcer.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS. Rute dan teks arahan fiktif, bukan data kampus.
class _ManualNavigation implements NavigationController {
  final _controller = StreamController<NavigationState>.broadcast();
  NavigationState _current = const NavigationState.idle();

  void emit(NavigationState state) {
    _current = state;
    _controller.add(state);
  }

  @override
  NavigationState get current => _current;

  @override
  Stream<NavigationState> get state => _controller.stream;

  @override
  Future<void> start(NavigationTarget target) async {}

  @override
  Future<void> stop() async {}
}

class _RecordingVoice extends FakeVoiceGuidance {
  int stops = 0;

  @override
  Future<void> stop() async => stops++;
}

/// Menghitung panggilan; [gate] menahan pemeriksaan suara agar urutan
/// kejadian dapat diatur.
class _CountingVoice implements VoiceGuidance {
  _CountingVoice({required this.available});

  final bool available;
  Completer<void>? gate;
  int checks = 0;
  int speakCalls = 0;
  int stops = 0;

  @override
  Future<bool> isAvailable() async {
    checks++;
    await gate?.future;
    return available;
  }

  @override
  Future<void> speak(String text) async => speakCalls++;

  @override
  Future<void> stop() async => stops++;
}

RouteStep _step(Maneuver maneuver, String text) => RouteStep(
  maneuver: maneuver,
  instruction: text,
  distanceM: 10,
  position: const GeoPoint(0, 0),
);

WalkingRoute _route(List<RouteStep> steps) => WalkingRoute(
  path: const [GeoPoint(0, 0), GeoPoint(0.001, 0)],
  distanceM: 111,
  eta: const Duration(seconds: 90),
  steps: steps,
);

const _poiTarget = NavigationTarget(
  id: 'synthetic-a',
  name: 'SINTETIS',
  kind: NavigationTargetKind.poi,
  point: GeoPoint(0, 0),
  isPlaceholderPoint: true,
);

const _facilityTarget = NavigationTarget(
  id: 'synthetic-f',
  name: 'SINTETIS',
  kind: NavigationTargetKind.facility,
  point: GeoPoint(0, 0),
  isPlaceholderPoint: false,
);

NavigationState _onRoute(
  WalkingRoute route,
  int index, {
  NavigationTarget target = _poiTarget,
}) => NavigationState(
  status: NavigationStatus.onRoute,
  target: target,
  route: route,
  currentStepIndex: index,
);

NavigationState _status(
  NavigationStatus status, {
  NavigationTarget target = _poiTarget,
  WalkingRoute? route,
}) => NavigationState(status: status, target: target, route: route);

void main() {
  late _ManualNavigation navigation;
  late _RecordingVoice voice;
  late FakeAudioService audio;
  late NavigationAnnouncer announcer;

  final route = _route([
    _step(Maneuver.depart, 'Mulai berjalan ke utara'),
    _step(Maneuver.turnLeft, 'Belok kiri'),
    _step(Maneuver.arrive, 'Tujuan di depan'),
  ]);

  setUp(() {
    navigation = _ManualNavigation();
    voice = _RecordingVoice();
    audio = FakeAudioService(tick: const Duration(hours: 1));
    announcer = NavigationAnnouncer(
      navigation: navigation,
      voice: voice,
      audio: audio,
    )..start();
  });

  tearDown(() async {
    await announcer.dispose();
    audio.dispose();
  });

  Future<void> emit(NavigationState state) async {
    navigation.emit(state);
    await pumpEventQueue();
  }

  test('membacakan setiap langkah sekali saat langkah berganti', () async {
    await emit(_onRoute(route, 0));
    await emit(_onRoute(route, 0));
    await emit(_onRoute(route, 1));
    await emit(_onRoute(route, 1));
    expect(voice.spoken, ['Mulai berjalan ke utara', 'Belok kiri']);
  });

  test('langkah arrive tidak dibacakan TTS', () async {
    await emit(_onRoute(route, 2));
    expect(voice.spoken, isEmpty);
  });

  test('rute baru setelah rerouting membacakan langkah pertamanya', () async {
    await emit(_onRoute(route, 1));
    await emit(_status(NavigationStatus.offRoute, route: route));
    await emit(_status(NavigationStatus.rerouting));
    final rerouted = _route([
      _step(Maneuver.depart, 'Putar balik'),
      _step(Maneuver.arrive, 'Tujuan di depan'),
    ]);
    await emit(_onRoute(rerouted, 0));
    expect(voice.spoken, ['Belok kiri', 'Putar balik']);
  });

  test(
    'tiba di POI: TTS berhenti lalu audio pengumuman tiba diputar',
    () async {
      await emit(_onRoute(route, 1));
      await emit(_status(NavigationStatus.arrived, route: route));
      expect(voice.stops, 1);
      expect(audio.current.clip?.poiId, 'synthetic-a');
      expect(audio.current.clip?.kind, AudioClipKind.arrival);
    },
  );

  test('status tiba berulang tidak memutar ulang pengumuman', () async {
    await emit(_status(NavigationStatus.arrived));
    await audio.stop();
    await emit(_status(NavigationStatus.arrived));
    expect(audio.current.status, PlaybackStatus.idle);
  });

  // PRD §10 [CL] 24 November 2026: tiba di fasilitas diumumkan dengan TTS
  // (sebelumnya hanya konfirmasi visual).
  test(
    'tiba di fasilitas: kalimat tiba dibacakan TTS, tanpa file audio',
    () async {
      await emit(_onRoute(route, 1, target: _facilityTarget));
      await emit(_status(NavigationStatus.arrived, target: _facilityTarget));
      expect(voice.spoken, ['Belok kiri', 'Anda telah tiba di SINTETIS']);
      expect(voice.stops, 1);
      expect(audio.current.status, PlaybackStatus.idle);
    },
  );

  test(
    'tiba di fasilitas tanpa suara id-ID: tidak ada yang dibacakan',
    () async {
      final silent = _CountingVoice(available: false);
      await announcer.dispose();
      announcer = NavigationAnnouncer(
        navigation: navigation,
        voice: silent,
        audio: audio,
      )..start();
      await emit(_status(NavigationStatus.arrived, target: _facilityTarget));
      expect(silent.checks, 1);
      expect(silent.speakCalls, 0);
      expect(audio.current.status, PlaybackStatus.idle);
    },
  );

  test('tiba di POI: hanya file audio, kalimat tiba tidak dibacakan', () async {
    await emit(_status(NavigationStatus.arrived));
    expect(voice.spoken, isEmpty);
    expect(audio.current.clip?.kind, AudioClipKind.arrival);
  });

  test('status tiba berulang di fasilitas diumumkan sekali', () async {
    await emit(_status(NavigationStatus.arrived, target: _facilityTarget));
    await emit(_status(NavigationStatus.arrived, target: _facilityTarget));
    await emit(_status(NavigationStatus.arrived, target: _facilityTarget));
    expect(voice.spoken, ['Anda telah tiba di SINTETIS']);
  });

  test('navigasi berakhir saat suara diperiksa: tidak dibacakan', () async {
    final slow = _CountingVoice(available: true);
    await announcer.dispose();
    announcer = NavigationAnnouncer(
      navigation: navigation,
      voice: slow,
      audio: audio,
    )..start();
    slow.gate = Completer<void>();
    navigation.emit(_status(NavigationStatus.arrived, target: _facilityTarget));
    await pumpEventQueue();
    await emit(const NavigationState.idle());
    slow.gate!.complete();
    await pumpEventQueue();
    expect(slow.speakCalls, 0);
  });

  test('race onRoute -> arrived saat isAvailable berjalan: langkah lama tidak dibacakan', () async {
    final slow = _CountingVoice(available: true);
    await announcer.dispose();
    announcer = NavigationAnnouncer(
      navigation: navigation,
      voice: slow,
      audio: audio,
    )..start();
    slow.gate = Completer<void>();
    navigation.emit(_onRoute(route, 0));
    await pumpEventQueue();
    navigation.emit(_status(NavigationStatus.arrived, route: route));
    await pumpEventQueue();
    slow.gate!.complete();
    await pumpEventQueue();
    expect(slow.speakCalls, 0);
    expect(slow.stops, 1);
    expect(audio.current.clip?.poiId, 'synthetic-a');
    expect(audio.current.clip?.kind, AudioClipKind.arrival);
  });

  test('race onRoute -> idle/error saat isAvailable berjalan: langkah lama tidak dibacakan', () async {
    final slow = _CountingVoice(available: true);
    await announcer.dispose();
    announcer = NavigationAnnouncer(
      navigation: navigation,
      voice: slow,
      audio: audio,
    )..start();
    slow.gate = Completer<void>();
    navigation.emit(_onRoute(route, 0));
    await pumpEventQueue();
    navigation.emit(const NavigationState.idle());
    await pumpEventQueue();
    slow.gate!.complete();
    await pumpEventQueue();
    expect(slow.speakCalls, 0);
    expect(slow.stops, 1);

    slow.gate = Completer<void>();
    navigation.emit(_onRoute(route, 1));
    await pumpEventQueue();
    navigation.emit(_status(NavigationStatus.error));
    await pumpEventQueue();
    slow.gate!.complete();
    await pumpEventQueue();
    expect(slow.speakCalls, 0);
    expect(slow.stops, 2);
  });

  test('tidak menabrak audio prompt atau arrival yang sedang diputar', () async {
    await audio.play(
      const AudioClip(poiId: 'synthetic-a', kind: AudioClipKind.prompt),
    );
    await emit(_onRoute(route, 0));
    expect(voice.spoken, isEmpty);

    // Setelah prompt berhenti, langkah berikutnya tetap dibacakan.
    await audio.stop();
    await emit(_onRoute(route, 1));
    expect(voice.spoken, ['Belok kiri']);

    // Audio arrival yang sedang diputar juga menahan langkah depart rute baru.
    await audio.play(
      const AudioClip(poiId: 'synthetic-a', kind: AudioClipKind.arrival),
    );
    final nextRoute = _route([
      _step(Maneuver.depart, 'Mulai berjalan ke selatan'),
      _step(Maneuver.turnRight, 'Belok kanan'),
    ]);
    await emit(_onRoute(nextRoute, 0));
    expect(voice.spoken, ['Belok kiri']);

    // Saat prompt/arrival dijeda (bukan playing), arahan tetap dibacakan.
    await audio.pause();
    await emit(_onRoute(nextRoute, 1));
    expect(voice.spoken, ['Belok kiri', 'Belok kanan']);
  });

  test('narasi yang sedang diputar tidak memblokir arahan navigasi', () async {
    await audio.play(
      const AudioClip(poiId: 'synthetic-a', kind: AudioClipKind.narration),
    );
    await emit(_onRoute(route, 0));
    expect(voice.spoken, ['Mulai berjalan ke utara']);
  });

  test('navigasi dihentikan: TTS berhenti dan langkah dilupakan', () async {
    await emit(_onRoute(route, 0));
    await emit(const NavigationState.idle());
    expect(voice.stops, 1);
    // Memulai lagi dengan rute yang sama membacakan langkah lagi.
    await emit(_onRoute(route, 0));
    expect(voice.spoken, [
      'Mulai berjalan ke utara',
      'Mulai berjalan ke utara',
    ]);
  });

  test('suara tidak tersedia: tidak ada yang dibacakan', () async {
    voice.available = false;
    await emit(_onRoute(route, 0));
    expect(voice.spoken, isEmpty);
  });

  test('bekerja dengan FakeNavigationController dari kontrak', () async {
    await announcer.dispose();
    final location = FakeLocationService(tick: const Duration(hours: 1));
    final fakeNavigation = FakeNavigationController(
      location: location,
      routing: FakeRoutingService(),
    );
    announcer = NavigationAnnouncer(
      navigation: fakeNavigation,
      voice: voice,
      audio: audio,
    )..start();
    await fakeNavigation.start(_poiTarget);
    await pumpEventQueue();
    expect(fakeNavigation.current.status, NavigationStatus.onRoute);
    expect(voice.spoken, isNotEmpty);
    location.dispose();
  });
}
