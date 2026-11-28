import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'agam_motion.dart';

/// Swaps content that belongs to something arriving elsewhere on screen, such
/// as a place name while the map camera travels to that place.
///
/// When [id] changes, the old content dissolves (fade and a 2 px blur) over
/// most of [arriveAfter] and the new content resolves only after it, so it
/// lands together with the thing it names instead of before it. Changes under the same [id]
/// (a live distance, an ETA) update in place without animating. Reduced
/// motion keeps a short opacity crossfade and drops the blur and the wait.
class AgamArrival extends StatefulWidget {
  const AgamArrival({
    super.key,
    required this.id,
    required this.child,
    this.arriveAfter = Duration.zero,
  });

  final Object id;
  final Widget child;
  final Duration arriveAfter;

  @override
  State<AgamArrival> createState() => _AgamArrivalState();
}

class _AgamArrivalState extends State<AgamArrival>
    with SingleTickerProviderStateMixin {
  static const _out = Duration(milliseconds: 140);
  static const _in = Duration(milliseconds: 220);
  static const _reducedFade = Duration(milliseconds: 120);

  late final _visibility = AnimationController(vsync: this, value: 1);

  @override
  void initState() {
    super.initState();
    _shownId = widget.id;
    _shown = widget.child;
  }

  // Set in initState, not lazily: a lazy initializer would first run in
  // didUpdateWidget and capture the new id, skipping the transition.
  late Object _shownId;
  late Widget _shown;
  Timer? _arrival;

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(AgamArrival oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id == _shownId) {
      // Same subject: keep it visible and current, cancel a pending swap.
      _arrival?.cancel();
      _shown = widget.child;
      if (_visibility.value < 1 && !_visibility.isAnimating) {
        _fadeIn();
      }
      return;
    }
    if (oldWidget.id == widget.id && _arrival != null) {
      return; // Already waiting for this subject; build() reads widget.child.
    }
    _arrival?.cancel();
    final wait = _reduced || widget.arriveAfter < _out
        ? (_reduced ? _reducedFade : _out)
        : widget.arriveAfter;
    // The old content dissolves over most of the wait rather than vanishing
    // at once, so the card never sits blank while the camera travels.
    final out = _reduced
        ? _reducedFade
        : Duration(
            microseconds: math.max(
              _out.inMicroseconds,
              (wait.inMicroseconds * .85).round(),
            ),
          );
    _visibility.animateTo(0, duration: out, curve: Curves.easeInOut);
    _arrival = Timer(wait, _land);
  }

  void _land() {
    if (!mounted) return;
    setState(() {
      _arrival = null;
      _shownId = widget.id;
      _shown = widget.child;
    });
    _fadeIn();
  }

  void _fadeIn() => _visibility.animateTo(
    1,
    duration: _reduced ? _reducedFade : _in,
    curve: AgamMotion.easeOut,
  );

  @override
  void dispose() {
    _arrival?.cancel();
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = _reduced;
    return AnimatedBuilder(
      animation: _visibility,
      child: _shown,
      builder: (context, child) {
        final t = _visibility.value;
        final sigma = reduced ? 0.0 : (1 - t) * 2;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: sigma < .01
              ? child
              : ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: child,
                ),
        );
      },
    );
  }
}
