import 'dart:async';

import 'package:agam/logic/audio/agam_audio_handler.dart';
import 'package:agam/logic/audio/audio_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

/// SINTETIS: models just_audio retaining `playing` after completion and
/// auto-starting a new asset if the caller has not paused it first.
class _Player extends Fake implements AudioPlayer {
  final events = StreamController<PlaybackEvent>.broadcast();
  final positions = StreamController<Duration>.broadcast();
  final calls = <String>[];
  Completer<void>? pauseGate;
  Completer<void>? seekGate;
  @override
  bool playing = true;
  @override
  ProcessingState processingState = ProcessingState.completed;
  @override
  Duration position = const Duration(seconds: 60);
  @override
  Duration? duration = const Duration(seconds: 60);
  @override
  Duration get bufferedPosition => position;
  @override
  double get speed => 1;
  @override
  Stream<PlaybackEvent> get playbackEventStream => events.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Future<void> pause() async {
    calls.add('pause');
    playing = false;
    await pauseGate?.future;
  }

  @override
  Future<Duration?> setAsset(
    String path, {
    String? package,
    bool preload = true,
    Duration? initialPosition,
    dynamic tag,
  }) async {
    calls.add('load:$path');
    if (playing) calls.add('unwanted-autoplay');
    position = initialPosition ?? position;
    processingState = ProcessingState.ready;
    return duration;
  }

  @override
  Future<void> seek(Duration? target, {int? index}) async {
    calls.add('seek');
    await seekGate?.future;
    position = target!;
    processingState = ProcessingState.ready;
  }

  @override
  Future<void> play() async {
    calls.add('play');
    playing = true;
  }
}

void main() {
  test('a delayed old load cannot replace the newest asset', () async {
    final player = _Player();
    final handler = AgamAudioHandler(player: player);
    player.pauseGate = Completer<void>();
    final gate = player.pauseGate!;
    final first = handler.load('old', title: 'SINTETIS', subtitle: 'SINTETIS');
    final rejected = expectLater(first, throwsA(isA<AudioBackendException>()));
    await pumpEventQueue();
    player.pauseGate = null;
    await handler.load('new', title: 'SINTETIS', subtitle: 'SINTETIS');
    gate.complete();
    await rejected;
    expect(player.calls, ['pause', 'pause', 'load:new']);
    expect(handler.mediaItem.value?.id, 'new');
    await player.events.close();
    await player.positions.close();
  });

  test('pause cancels a pending restart from completion', () async {
    final player = _Player();
    final handler = AgamAudioHandler(player: player);
    player.seekGate = Completer<void>();
    final restarting = handler.play();
    await pumpEventQueue();
    await handler.pause();
    player.seekGate!.complete();
    await restarting;
    expect(player.calls, ['seek', 'pause']);
    expect(player.playing, isFalse);
    await player.events.close();
    await player.positions.close();
  });

  test(
    'new asset clears completed position and inherited playback intent',
    () async {
      final player = _Player();
      final handler = AgamAudioHandler(player: player);
      await handler.load(
        'synthetic-prompt',
        title: 'SINTETIS',
        subtitle: 'SINTETIS',
      );
      expect(player.calls, ['pause', 'load:synthetic-prompt']);
      expect(player.position, Duration.zero);
      expect(player.playing, isFalse);
      await handler.play();
      expect(player.calls.last, 'play');
      await player.events.close();
      await player.positions.close();
    },
  );

  test(
    'lock-screen play after completion seeks to start before playing',
    () async {
      final player = _Player();
      final handler = AgamAudioHandler(player: player);
      await handler.play();
      expect(player.calls, ['seek', 'play']);
      expect(player.position, Duration.zero);
      await player.events.close();
      await player.positions.close();
    },
  );
}
