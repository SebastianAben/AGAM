/// Implementasi asli [AudioService] (PB08).
library;

import 'dart:async';

import '../../contracts/contracts.dart';
import 'audio_backend.dart';
import 'audio_seek_control.dart';

/// Memutar narasi, prompt, dan pengumuman tiba milik POI dari aset APK.
///
/// Path file diambil dari `Poi.media` (PRD §10). Selama konten belum
/// tersedia, path bernilai `null` dan [play] memancarkan
/// [PlaybackStatus.error] tanpa melempar error, sehingga trigger tetap
/// berjalan dengan notifikasi dan getar saja.
class DeviceAudioService implements AudioService, AudioSeekControl {
  DeviceAudioService({required this._backend, required this._pois}) {
    _backendSubscription = _backend.snapshots.listen(_onSnapshot);
  }

  final AudioBackend _backend;
  final PoiRepository _pois;
  final _controller = StreamController<PlaybackState>.broadcast();
  late final StreamSubscription<BackendSnapshot> _backendSubscription;

  PlaybackState _current = const PlaybackState.idle();

  /// Menaikkan nomor setiap kali klip baru dimuat, agar snapshot dari klip
  /// sebelumnya tidak menimpa keadaan klip yang baru.
  int _generation = 0;
  int _seekGeneration = 0;
  int _loadedGeneration = -1;
  bool _wantsPlayback = false;

  @override
  PlaybackState get current => _current;

  @override
  Stream<PlaybackState> get state => _controller.stream;

  @override
  Future<void> play(AudioClip clip) async {
    final generation = ++_generation;
    _wantsPlayback = true;
    final poi = await _pois.poiById(clip.poiId);
    if (generation != _generation) return;
    final path = poi == null ? null : assetPathFor(poi, clip.kind);
    if (poi == null || path == null) {
      await _backend.stop();
      if (generation != _generation) return;
      _emit(PlaybackState(status: PlaybackStatus.error, clip: clip));
      return;
    }

    _emit(PlaybackState(status: PlaybackStatus.playing, clip: clip));
    try {
      final duration = await _backend.load(
        path,
        title: titleFor(poi, clip.kind),
        subtitle: 'AGAM',
      );
      if (generation != _generation) return;
      _loadedGeneration = generation;
      _emit(
        PlaybackState(
          status: _wantsPlayback
              ? PlaybackStatus.playing
              : PlaybackStatus.paused,
          clip: clip,
          duration: duration,
        ),
      );
      if (_wantsPlayback) await _backend.play();
    } on AudioBackendException {
      if (generation != _generation) return;
      _emit(PlaybackState(status: PlaybackStatus.error, clip: clip));
    }
  }

  @override
  Future<void> pause() async {
    if (_current.status != PlaybackStatus.playing) return;
    _wantsPlayback = false;
    _emit(
      PlaybackState(
        status: PlaybackStatus.paused,
        clip: _current.clip,
        position: _current.position,
        duration: _current.duration,
      ),
    );
    if (_loadedGeneration == _generation) await _backend.pause();
  }

  @override
  Future<void> resume() async {
    if (_current.status != PlaybackStatus.paused) return;
    _wantsPlayback = true;
    if (_loadedGeneration == _generation) await _backend.play();
  }

  @override
  Future<void> replay() async {
    final clip = _current.clip;
    if (clip == null) return;
    _wantsPlayback = true;
    if (_loadedGeneration == _generation &&
        _current.status != PlaybackStatus.error) {
      final generation = _generation;
      await _backend.seek(Duration.zero);
      if (generation != _generation || !_wantsPlayback) return;
      await _backend.play();
    } else {
      await play(clip);
    }
  }

  @override
  Future<void> seekTo(Duration position) async {
    final state = _current;
    final duration = state.duration;
    if (state.clip == null ||
        duration == null ||
        _loadedGeneration != _generation ||
        duration <= Duration.zero) {
      return;
    }
    final generation = _generation;
    final seekGeneration = ++_seekGeneration;
    final target = Duration(
      milliseconds: position.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    await _backend.seek(target);
    if (generation != _generation || seekGeneration != _seekGeneration) return;
    _emit(
      PlaybackState(
        status: _current.status == PlaybackStatus.completed
            ? PlaybackStatus.paused
            : _current.status,
        clip: state.clip,
        position: target,
        duration: duration,
      ),
    );
  }

  @override
  Future<void> stop() async {
    _generation++;
    _wantsPlayback = false;
    await _backend.stop();
    _emit(const PlaybackState.idle());
  }

  Future<void> dispose() async {
    await _backendSubscription.cancel();
    await _controller.close();
  }

  void _onSnapshot(BackendSnapshot snapshot) {
    final clip = _current.clip;
    if (clip == null || _loadedGeneration != _generation) return;
    if (_current.status == PlaybackStatus.error) return;
    final PlaybackStatus status;
    switch (snapshot.phase) {
      case BackendPhase.idle:
        return;
      case BackendPhase.completed:
        status = PlaybackStatus.completed;
      case BackendPhase.loading:
      case BackendPhase.ready:
        status = snapshot.playing
            ? PlaybackStatus.playing
            : PlaybackStatus.paused;
    }
    _emit(
      PlaybackState(
        status: status,
        clip: clip,
        position: status == PlaybackStatus.completed
            ? (snapshot.duration ?? snapshot.position)
            : snapshot.position,
        duration: snapshot.duration ?? _current.duration,
      ),
    );
  }

  void _emit(PlaybackState state) {
    _current = state;
    _controller.add(state);
  }

  static String? assetPathFor(Poi poi, AudioClipKind kind) {
    if (!poi.metadata.approved || poi.metadata.isPlaceholder) return null;
    final path = switch (kind) {
      AudioClipKind.narration => poi.media.narrationAudio,
      AudioClipKind.prompt => poi.media.promptAudio,
      AudioClipKind.arrival => poi.media.arrivalAudio,
    };
    return (path == null || path.trim().isEmpty) ? null : path;
  }

  /// Judul di notifikasi media dan lock screen.
  static String titleFor(Poi poi, AudioClipKind kind) => switch (kind) {
    AudioClipKind.narration => 'Narasi ${poi.name}',
    AudioClipKind.prompt => poi.name,
    AudioClipKind.arrival => 'Tiba di ${poi.name}',
  };
}
