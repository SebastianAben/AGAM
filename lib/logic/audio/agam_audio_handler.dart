/// Backend audio asli: `just_audio` untuk pemutaran dan `audio_service`
/// untuk kontrol dari notifikasi dan lock screen (PB08, F04).
library;

import 'dart:async';

import 'package:audio_service/audio_service.dart' as svc;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_backend.dart';

/// Satu pemutar untuk seluruh klip POI. Tombol putar/jeda/berhenti di
/// notifikasi media dan lock screen diteruskan ke pemutar yang sama, lalu
/// keadaannya dipancarkan lewat [snapshots] ke `DeviceAudioService`.
class AgamAudioHandler extends svc.BaseAudioHandler
    with svc.SeekHandler
    implements AudioBackend {
  AgamAudioHandler({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _player.playbackEventStream.listen(
      (_) => _publish(),
      onError: (Object _, StackTrace _) => _publish(),
    );
    _player.positionStream.listen((_) => _emitSnapshot());
  }

  /// Memulai audio_service dan mengembalikan handler tunggal aplikasi.
  /// Dipanggil sekali saat aplikasi mulai.
  static Future<AgamAudioHandler> init() => svc.AudioService.init(
    builder: AgamAudioHandler.new,
    config: const svc.AudioServiceConfig(
      androidNotificationChannelId: 'site.agam.audio',
      androidNotificationChannelName: 'Narasi AGAM',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  final AudioPlayer _player;
  final _snapshots = StreamController<BackendSnapshot>.broadcast();

  @override
  Stream<BackendSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<Duration?> load(
    String assetPath, {
    required String title,
    required String subtitle,
  }) async {
    try {
      final duration = await _player.setAsset(assetPath);
      mediaItem.add(
        svc.MediaItem(
          id: assetPath,
          title: title,
          album: subtitle,
          duration: duration,
        ),
      );
      return duration;
    } on PlayerException catch (e) {
      throw AudioBackendException(e.message ?? 'Gagal memuat $assetPath');
    } on PlatformException catch (e) {
      throw AudioBackendException(e.message ?? 'Gagal memuat $assetPath');
    } on PlayerInterruptedException {
      throw AudioBackendException('Pemuatan $assetPath dibatalkan');
    }
  }

  // `_player.play()` baru selesai saat pemutaran berhenti, jadi tidak
  // ditunggu.
  @override
  Future<void> play() async => unawaited(_player.play());

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    mediaItem.add(null);
    await super.stop();
  }

  void _publish() {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          playing ? svc.MediaControl.pause : svc.MediaControl.play,
          svc.MediaControl.stop,
        ],
        systemActions: const {svc.MediaAction.seek},
        androidCompactActionIndices: const [0, 1],
        processingState: switch (_player.processingState) {
          ProcessingState.idle => svc.AudioProcessingState.idle,
          ProcessingState.loading => svc.AudioProcessingState.loading,
          ProcessingState.buffering => svc.AudioProcessingState.buffering,
          ProcessingState.ready => svc.AudioProcessingState.ready,
          ProcessingState.completed => svc.AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
    _emitSnapshot();
  }

  void _emitSnapshot() {
    _snapshots.add(
      BackendSnapshot(
        phase: switch (_player.processingState) {
          ProcessingState.idle => BackendPhase.idle,
          ProcessingState.loading ||
          ProcessingState.buffering => BackendPhase.loading,
          ProcessingState.ready => BackendPhase.ready,
          ProcessingState.completed => BackendPhase.completed,
        },
        playing: _player.playing,
        position: _player.position,
        duration: _player.duration,
      ),
    );
  }
}
