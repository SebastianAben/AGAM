import 'dart:io';

import 'package:agam/ui/widgets/narration_wave.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
