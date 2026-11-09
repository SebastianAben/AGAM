import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/logic/audio/audio_backend.dart';
import 'package:agam/logic/audio/device_audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic.dart';

class _FakeBackend implements AudioBackend {
  final _snapshots = StreamController<BackendSnapshot>.broadcast();
  final calls = <String>[];
  Duration? duration = const Duration(seconds: 60);
  bool failLoad = false;
  Completer<void>? loadGate;
  String? lastTitle;

  @override
  Stream<BackendSnapshot> get snapshots => _snapshots.stream;

  void emit(BackendSnapshot snapshot) => _snapshots.add(snapshot);

  @override
  Future<Duration?> load(
    String assetPath, {
    required String title,
    required String subtitle,
  }) async {
    calls.add('load:$assetPath');
    lastTitle = title;
    final gate = loadGate;
    if (gate != null) await gate.future;
    if (failLoad) throw const AudioBackendException('tidak ada');
    return duration;
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration position) async => calls.add('seek:$position');

  @override
  Future<void> stop() async => calls.add('stop');
}

// SINTETIS. Path aset fiktif; tidak ada file audio sungguhan.
const _media = PoiMedia(
  narrationAudio: 'assets/media/synthetic/narasi.mp3',
  promptAudio: 'assets/media/synthetic/prompt.mp3',
);

void main() {
  late _FakeBackend backend;
  late DeviceAudioService audio;

  setUp(() {
    backend = _FakeBackend();
    audio = DeviceAudioService(
      backend: backend,
      pois: FakePoiRepository(
        pois: [
          syntheticPoi(media: _media, name: 'Gedung Sintetis'),
          syntheticPoi(id: 'placeholder'),
        ],
      ),
    );
  });

  tearDown(() => audio.dispose());

  const narration = AudioClip(
    poiId: 'synthetic-a',
    kind: AudioClipKind.narration,
  );

  test('memutar narasi dari path aset POI', () async {
    await audio.play(narration);
    expect(backend.calls, ['load:assets/media/synthetic/narasi.mp3', 'play']);
    expect(backend.lastTitle, 'Narasi Gedung Sintetis');
    expect(audio.current.status, PlaybackStatus.playing);
    expect(audio.current.clip, narration);
    expect(audio.current.duration, const Duration(seconds: 60));
  });

  test('konten placeholder tanpa file → error tanpa melempar', () async {
    await audio.play(
      const AudioClip(poiId: 'placeholder', kind: AudioClipKind.narration),
    );
    expect(audio.current.status, PlaybackStatus.error);
    expect(backend.calls, ['stop']);
  });

  test('klip yang tidak punya path (arrival) → error', () async {
    await audio.play(
      const AudioClip(poiId: 'synthetic-a', kind: AudioClipKind.arrival),
    );
    expect(audio.current.status, PlaybackStatus.error);
  });

  test('POI tidak dikenal → error', () async {
    await audio.play(
      const AudioClip(poiId: 'tidak-ada', kind: AudioClipKind.prompt),
    );
    expect(audio.current.status, PlaybackStatus.error);
  });

  test('aset gagal dimuat → error', () async {
    backend.failLoad = true;
    await audio.play(narration);
    expect(audio.current.status, PlaybackStatus.error);
    expect(backend.calls, isNot(contains('play')));
  });

  test('jeda, lanjut, dan selesai mengikuti snapshot pemutar', () async {
    await audio.play(narration);
    backend.emit(
      const BackendSnapshot(
        phase: BackendPhase.ready,
        playing: true,
        position: Duration(seconds: 10),
        duration: Duration(seconds: 60),
      ),
    );
    await pumpEventQueue();
    expect(audio.current.position, const Duration(seconds: 10));

    await audio.pause();
    expect(backend.calls.last, 'pause');
    backend.emit(
      const BackendSnapshot(
        phase: BackendPhase.ready,
        playing: false,
        position: Duration(seconds: 10),
      ),
    );
    await pumpEventQueue();
    expect(audio.current.status, PlaybackStatus.paused);

    await audio.resume();
    expect(backend.calls.last, 'play');

    backend.emit(
      const BackendSnapshot(
        phase: BackendPhase.completed,
        playing: false,
        position: Duration(seconds: 60),
        duration: Duration(seconds: 60),
      ),
    );
    await pumpEventQueue();
    expect(audio.current.status, PlaybackStatus.completed);
  });

  test('jeda dari notifikasi/lock screen tercermin di state', () async {
    await audio.play(narration);
    backend.emit(
      const BackendSnapshot(
        phase: BackendPhase.ready,
        playing: false,
        position: Duration(seconds: 3),
      ),
    );
    await pumpEventQueue();
    expect(audio.current.status, PlaybackStatus.paused);
  });

  test('replay memutar dari awal', () async {
    await audio.play(narration);
    await audio.replay();
    expect(backend.calls.sublist(2), ['seek:0:00:00.000000', 'play']);
  });

  test('stop mengembalikan idle', () async {
    await audio.play(narration);
    await audio.stop();
    expect(audio.current.status, PlaybackStatus.idle);
    expect(backend.calls.last, 'stop');
  });

  test('klip baru menggantikan klip yang masih dimuat', () async {
    final gate = backend.loadGate = Completer<void>();
    final first = audio.play(narration);
    await pumpEventQueue();
    backend.loadGate = null;
    const prompt = AudioClip(poiId: 'synthetic-a', kind: AudioClipKind.prompt);
    await audio.play(prompt);
    // Pemuatan pertama baru selesai setelah klip kedua mulai; hasilnya
    // tidak boleh menimpa klip kedua.
    gate.complete();
    await first;
    expect(audio.current.clip, prompt);
    expect(audio.current.status, PlaybackStatus.playing);
    expect(backend.calls.where((c) => c == 'play'), hasLength(1));
  });

  test('snapshot klip lama diabaikan setelah stop', () async {
    await audio.play(narration);
    await audio.stop();
    backend.emit(
      const BackendSnapshot(phase: BackendPhase.ready, playing: true),
    );
    await pumpEventQueue();
    expect(audio.current.status, PlaybackStatus.idle);
  });

  test('judul notifikasi per jenis klip', () {
    final poi = syntheticPoi(name: 'Gedung Sintetis');
    expect(
      DeviceAudioService.titleFor(poi, AudioClipKind.prompt),
      'Gedung Sintetis',
    );
    expect(
      DeviceAudioService.titleFor(poi, AudioClipKind.arrival),
      'Tiba di Gedung Sintetis',
    );
  });
}
