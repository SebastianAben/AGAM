import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/ui/poi_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

// SINTETIS: no real content, plugin or production asset is used here. The
// video path is never opened; the fake platform below answers instead.
const _videoPath = 'synthetic/video.mp4';

Poi _poi({String? video = _videoPath, bool approved = true}) => Poi(
  id: 'synthetic-video',
  name: 'SINTETIS',
  aliases: const [],
  category: PoiCategory.lecture,
  position: const GeoPoint(0, 0),
  radiusM: 15,
  entrances: const [],
  description: 'SINTETIS deskripsi',
  function: 'SINTETIS fungsi',
  facilities: const [],
  trivia: 'SINTETIS trivia',
  media: PoiMedia(narrationAudio: 'synthetic.mp3', video: video),
  metadata: ContentMetadata(
    sources: const ['SINTETIS'],
    verifiedAt: null,
    owner: 'SINTETIS',
    assetAttribution: const [],
    approved: approved,
    isPlaceholder: !approved,
  ),
);

/// Pattern from video_player 2.14.1 `test/video_player_test.dart`
/// (`FakeVideoPlayerPlatform`), reduced to the calls this widget makes.
class _FakeVideoPlatform extends VideoPlayerPlatform {
  final calls = <String>[];
  final dataSources = <DataSource>[];
  final _streams = <int, StreamController<VideoEvent>>{};
  bool failNext = false;
  int _nextId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    calls.add('create');
    dataSources.add(options.dataSource);
    final stream = StreamController<VideoEvent>();
    _streams[_nextId] = stream;
    if (failNext) {
      failNext = false;
      stream.addError(
        PlatformException(code: 'VideoError', message: 'SINTETIS galat'),
      );
    } else {
      // Portrait, like the bundled GKUB clip; duration is synthetic.
      stream.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(576, 1024),
          duration: const Duration(seconds: 90),
        ),
      );
    }
    return _nextId++;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _streams[playerId]!.stream;

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> dispose(int playerId) async => calls.add('dispose');

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      calls.add('seekTo');

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool preventsDisplaySleepDuringVideoPlayback,
  ) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);
}

class _Audio implements AudioService {
  final _events = StreamController<PlaybackState>.broadcast();
  final calls = <String>[];

  @override
  PlaybackState current = const PlaybackState.idle();

  @override
  Stream<PlaybackState> get state => _events.stream;

  void _set(PlaybackState next) {
    current = next;
    _events.add(next);
  }

  @override
  Future<void> play(AudioClip clip) async {
    calls.add('play');
    _set(
      PlaybackState(
        status: PlaybackStatus.playing,
        clip: clip,
        duration: const Duration(seconds: 60),
      ),
    );
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _set(
      PlaybackState(
        status: PlaybackStatus.paused,
        clip: current.clip,
        duration: current.duration,
        position: current.position,
      ),
    );
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    _set(
      PlaybackState(
        status: PlaybackStatus.playing,
        clip: current.clip,
        duration: current.duration,
        position: current.position,
      ),
    );
  }

  @override
  Future<void> replay() async => calls.add('replay');

  @override
  Future<void> stop() async {
    calls.add('stop');
    _set(const PlaybackState.idle());
  }
}

void main() {
  late _FakeVideoPlatform platform;

  setUp(() {
    platform = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  Future<_Audio> pumpDetail(WidgetTester tester, Poi poi) async {
    final audio = _Audio();
    // Tall phone viewport so the lazily built list includes the video card.
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: PoiDetailScreen(
          poi: poi,
          audio: audio,
          onNavigate: () async {},
          checkedIn: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return audio;
  }

  Future<void> tapVideoPlay(WidgetTester tester) async {
    final play = find.byTooltip('Putar video').first;
    await tester.ensureVisible(play);
    await tester.pumpAndSettle();
    await tester.tap(play);
    await tester.pump();
    await tester.pump();
  }

  /// Disposes the screen so the controller's position timer stops.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // The controller cancels its event subscription before calling the
    // platform's dispose; that completes outside the fake clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }

  testWidgets('video section appears only for approved POI with a video', (
    tester,
  ) async {
    await pumpDetail(tester, _poi(video: null));
    expect(find.text('Video'), findsNothing);

    await pumpDetail(tester, _poi(approved: false));
    expect(find.text('Video'), findsNothing);
    expect(find.byTooltip('Putar video'), findsNothing);

    await pumpDetail(tester, _poi());
    expect(find.text('Video'), findsOneWidget);
    expect(find.byTooltip('Putar video'), findsOneWidget);
    // Opening the card does not load or play the video.
    expect(platform.calls, isEmpty);
  });

  testWidgets('tap loads the bundled asset, plays, and toggles pause', (
    tester,
  ) async {
    await pumpDetail(tester, _poi());
    await tapVideoPlay(tester);

    expect(platform.dataSources.single.sourceType, DataSourceType.asset);
    expect(platform.dataSources.single.asset, _videoPath);
    expect(platform.calls, containsAllInOrder(['create', 'play']));
    expect(find.byTooltip('Jeda video'), findsOneWidget);
    expect(find.text('0:00 / 1:30'), findsOneWidget);

    await tester.tap(find.byTooltip('Jeda video'));
    await tester.pump();
    expect(platform.calls.last, 'pause');
    expect(find.byTooltip('Jeda video'), findsNothing);

    await unmount(tester);
    expect(platform.calls.last, 'dispose');
  });

  testWidgets('video pauses POI audio, and new audio pauses the video', (
    tester,
  ) async {
    final audio = await pumpDetail(tester, _poi());
    await audio.play(
      const AudioClip(poiId: 'synthetic-video', kind: AudioClipKind.prompt),
    );
    await tester.pump();

    await tapVideoPlay(tester);
    expect(audio.calls, ['play', 'pause']);
    expect(platform.calls.last, 'play');

    await audio.resume();
    await tester.pump();
    expect(platform.calls.last, 'pause');
    expect(find.byTooltip('Jeda video'), findsNothing);

    await unmount(tester);
  });

  testWidgets('fullscreen reuses the controller and keeps it on close', (
    tester,
  ) async {
    await pumpDetail(tester, _poi());
    await tapVideoPlay(tester);

    await tester.tap(find.byTooltip('Layar penuh'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tutup layar penuh'), findsOneWidget);
    expect(platform.calls.where((call) => call == 'create'), hasLength(1));

    await tester.tap(find.byTooltip('Tutup layar penuh'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tutup layar penuh'), findsNothing);
    expect(platform.calls, isNot(contains('dispose')));
    expect(find.byTooltip('Jeda video'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('load failure shows an Indonesian message and can retry', (
    tester,
  ) async {
    await pumpDetail(tester, _poi());
    platform.failNext = true;
    await tapVideoPlay(tester);
    await tester.pump();

    expect(find.text('Video belum dapat diputar.'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Video belum dapat diputar.'), findsNothing);
    expect(find.byTooltip('Jeda video'), findsOneWidget);

    await unmount(tester);
  });
}
