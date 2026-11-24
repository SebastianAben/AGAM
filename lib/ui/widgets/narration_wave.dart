import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Loudness of a narration over time, five frequency bands per frame.
///
/// Built from the real audio by `tool/build_narration_waves.py` and stored
/// next to it as `<name>.wave.json`, so the bars follow what is heard.
class NarrationEnvelope {
  NarrationEnvelope._(this.fps, this.bands, this._frames);

  final int fps;
  final int bands;
  final List<List<double>> _frames;

  static final _cache = <String, Future<NarrationEnvelope?>>{};

  /// Envelope path for an audio asset: same folder and name, `.wave.json`.
  static String pathFor(String audioPath) =>
      audioPath.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '.wave.json');

  /// Loads the envelope for [audioPath]. Returns null when it is missing or
  /// malformed, so callers fall back to a static icon instead of faking it.
  static Future<NarrationEnvelope?> load(String audioPath) =>
      _cache.putIfAbsent(audioPath, () async {
        try {
          final raw = await rootBundle.loadString(pathFor(audioPath));
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final fps = json['fps'] as int;
          final bands = json['bands'] as int;
          final frames = [
            for (final frame in json['frames'] as List)
              [for (final v in frame as List) (v as num) / 100],
          ];
          if (fps <= 0 || bands <= 0) return null;
          if (frames.any((f) => f.length != bands)) return null;
          return NarrationEnvelope._(fps, bands, frames);
        } catch (_) {
          return null;
        }
      });

  /// Band levels (0–1) at [position], interpolated between frames.
  List<double> at(Duration position, List<double> into) {
    final f = position.inMicroseconds / 1e6 * fps;
    final i = f.floor();
    if (i < 0 || i >= _frames.length) {
      into.fillRange(0, into.length, 0);
      return into;
    }
    final a = _frames[i];
    final b = i + 1 < _frames.length ? _frames[i + 1] : a;
    final t = f - i;
    for (var k = 0; k < into.length && k < bands; k++) {
      into[k] = a[k] + (b[k] - a[k]) * t;
    }
    return into;
  }
}

/// Five bars that move with the narration that is playing.
///
/// Position updates from the player arrive every few dozen milliseconds, so
/// a ticker extrapolates between them and eases each bar towards its band
/// level: fast attack, slower release, like a real level meter. The ticker
/// only runs while the narration plays (and briefly after, to let the bars
/// fall), never as an idle loop.
class NarrationWave extends StatefulWidget {
  const NarrationWave({
    super.key,
    required this.envelope,
    required this.playing,
    required this.position,
    required this.color,
    this.size = 20,
  });

  final NarrationEnvelope envelope;
  final bool playing;
  final Duration position;
  final Color color;
  final double size;

  @override
  State<NarrationWave> createState() => _NarrationWaveState();
}

class _NarrationWaveState extends State<NarrationWave>
    with SingleTickerProviderStateMixin {
  /// Without a fresh position for this long (buffering, a stalled player),
  /// the bars stop advancing instead of running ahead of the audio.
  static const _staleAfter = Duration(milliseconds: 400);
  static const _attack = .035;
  static const _release = .14;

  late final Ticker _ticker = createTicker(_tick);
  late final _levels = _Levels(widget.envelope.bands);
  late final List<double> _targets = List.filled(widget.envelope.bands, 0);

  late Duration _anchor = widget.position;
  Duration _sinceAnchor = Duration.zero;
  Duration _lastElapsed = Duration.zero;

  bool get _advancing => widget.playing && _sinceAnchor <= _staleAfter;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant NarrationWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != oldWidget.position ||
        widget.playing != oldWidget.playing) {
      _anchor = widget.position;
      _sinceAnchor = Duration.zero;
    }
    _sync();
  }

  void _sync() {
    if (_ticker.isActive || (!_advancing && _settled)) return;
    _lastElapsed = Duration.zero;
    _ticker.start();
  }

  bool get _settled {
    final values = _levels.values;
    for (var i = 0; i < values.length; i++) {
      final target = widget.playing ? _targets[i] : 0.0;
      if ((values[i] - target).abs() > .004) return false;
    }
    return true;
  }

  void _tick(Duration elapsed) {
    final step = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    _sinceAnchor += step;
    final dt = step.inMicroseconds / 1e6;
    final ahead = _sinceAnchor < _staleAfter ? _sinceAnchor : _staleAfter;
    if (widget.playing) {
      widget.envelope.at(_anchor + ahead, _targets);
    } else {
      _targets.fillRange(0, _targets.length, 0);
    }
    final values = _levels.values;
    for (var i = 0; i < values.length; i++) {
      final rising = _targets[i] > values[i];
      final k = 1 - math.exp(-dt / (rising ? _attack : _release));
      values[i] += (_targets[i] - values[i]) * k;
    }
    _levels.notify();
    if (!_advancing && _settled) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _levels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: _WavePainter(_levels, widget.color),
    ),
  );
}

class _Levels extends ChangeNotifier {
  _Levels(int bands) : values = List.filled(bands, 0);

  final List<double> values;

  void notify() => notifyListeners();
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.levels, this.color) : super(repaint: levels);

  final _Levels levels;
  final Color color;

  /// Lowest bands in the middle, highest at the edges, so speech reads as
  /// the familiar equaliser silhouette.
  static const _order = [3, 1, 0, 2, 4];

  @override
  void paint(Canvas canvas, Size size) {
    final count = math.min(_order.length, levels.values.length);
    final barWidth = size.width * .125;
    final gap = size.width * .075;
    final total = count * barWidth + (count - 1) * gap;
    final minHeight = barWidth;
    final maxHeight = size.height * .85;
    final paint = Paint()..color = color;
    var x = (size.width - total) / 2;
    for (var i = 0; i < count; i++) {
      final band = _order[i] < levels.values.length ? _order[i] : i;
      final level = levels.values[band].clamp(0.0, 1.0);
      final height = minHeight + (maxHeight - minHeight) * level;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - height) / 2, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.levels != levels || oldDelegate.color != color;
}
