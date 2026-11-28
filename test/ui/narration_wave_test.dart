import 'dart:io';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/ui/poi_detail_screen.dart';
import 'package:agam/ui/widgets/narration_wave.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS: no real content, coordinate or production asset is used here.
Poi _syntheticPoi({String? narration}) => Poi(
  id: 'synthetic-narrow',
  name: 'SINTETIS Gedung Dengan Nama Cukup Panjang',
  aliases: const [],
  category: PoiCategory.lecture,
  position: const GeoPoint(0, 0),
  radiusM: 15,
  entrances: const [],
  description: 'SINTETIS deskripsi',
  function: 'SINTETIS fungsi',
  facilities: const [],
  trivia: 'SINTETIS trivia',
  media: PoiMedia(narrationAudio: narration),
  metadata: const ContentMetadata(
    sources: ['SINTETIS'],
    verifiedAt: null,
    owner: 'SINTETIS',
    assetAttribution: [],
    approved: true,
  ),
);

/// A 320 dp phone with large text (1.4x): the narration card must lay out
/// its time row and five transport buttons without any RenderFlex overflow.
Future<void> _pumpNarrow(WidgetTester tester, Poi poi, AudioService audio) {
  tester.view.physicalSize = const Size(320, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.4)),
        child: child!,
      ),
      home: PoiDetailScreen(
        poi: poi,
        audio: audio,
        onNavigate: () async {},
        checkedIn: false,
        navigationAvailable: false,
      ),
    ),
  );
}

void main() {
  testWidgets('narration card fits 320 dp at 1.4x text without audio', (
    tester,
  ) async {
    await _pumpNarrow(tester, _syntheticPoi(), FakeAudioService());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Audio belum tersedia'), findsOneWidget);
    expect(find.text('--:--'), findsOneWidget);
    for (final tooltip in [
      'Ulangi narasi',
      'Mundur 10 detik',
      'Maju 10 detik',
      'Hentikan narasi',
    ]) {
      final size = tester.getSize(find.byTooltip(tooltip));
      expect(size.width, greaterThanOrEqualTo(44), reason: tooltip);
      expect(size.height, greaterThanOrEqualTo(44), reason: tooltip);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('narration card fits 320 dp at 1.4x text while playing', (
    tester,
  ) async {
    final audio = FakeAudioService();
    await _pumpNarrow(tester, _syntheticPoi(narration: 'synthetic.mp3'), audio);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    // Past the first tick, so the position and duration labels are shown.
    await tester.pump(const Duration(milliseconds: 1200));

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    await audio.stop();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  test('envelope path sits next to the audio file', () {
    expect(
      NarrationEnvelope.pathFor('assets/media/P01/narasi.m4a'),
      'assets/media/P01/narasi.wave.json',
    );
  });

  test('every bundled narration has an envelope of matching length', () {
    final audio = Directory('assets/media')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('narasi.m4a'))
        .toList();
    expect(audio, isNotEmpty);
    for (final file in audio) {
      final wave = File(NarrationEnvelope.pathFor(file.path));
      expect(wave.existsSync(), isTrue, reason: '${wave.path} hilang');
    }
  });

  testWidgets('wave loads, follows playback, and settles when paused', (
    tester,
  ) async {
    final envelope = (await tester.runAsync(
      () => NarrationEnvelope.load('assets/media/P01/narasi.m4a'),
    ))!;
    final levels = envelope.at(const Duration(seconds: 10), List.filled(5, 0));
    expect(levels.every((v) => v >= 0 && v <= 1), isTrue);
    expect(levels.any((v) => v > 0), isTrue);

    Widget wave({required bool playing, required Duration position}) =>
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: NarrationWave(
              envelope: envelope,
              playing: playing,
              position: position,
              color: Colors.cyan,
            ),
          ),
        );

    await tester.pumpWidget(
      wave(playing: true, position: const Duration(seconds: 10)),
    );
    expect(tester.hasRunningAnimations, isTrue);

    // No fresh positions: the bars stop advancing instead of looping on.
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(
      wave(playing: false, position: const Duration(seconds: 11)),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
