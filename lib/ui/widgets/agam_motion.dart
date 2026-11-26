import 'dart:ui' show ImageFilter;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

abstract final class AgamMotion {
  static const easeOut = Cubic(0.23, 1, 0.32, 1);
  static const drawer = Cubic(0.32, 0.72, 0, 1);

  /// Ease-in-out for things travelling across the screen (a map camera moving
  /// between two places): it leaves gently, cruises and settles.
  static const travel = Cubic(0.65, 0, 0.35, 1);

  static Duration duration(BuildContext context, [int milliseconds = 220]) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);

  static Widget panel(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );

  /// Transition for an [AnimatedSwitcher] that swaps one icon for another in
  /// the same slot: the new glyph grows from 70 % while fading in and a 2 px
  /// blur that clears as it lands, so the two glyphs read as one shape
  /// morphing instead of two icons overlapping.
  static Widget iconSwap(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: easeOut);
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final t = curved.value;
        final sigma = (1 - t) * 2;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: .7 + .3 * t,
            child: sigma < .01
                ? child
                : ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: child,
                  ),
          ),
        );
      },
    );
  }

  /// Pushed pages slide along the horizontal axis they were opened on;
  /// reduced motion swaps the slide for an instant change.
  static Route<T> route<T>(WidgetBuilder builder) => PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, secondary, child) =>
        MediaQuery.disableAnimationsOf(context)
        ? child
        : SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondary,
            transitionType: SharedAxisTransitionType.horizontal,
            fillColor: Colors.transparent,
            child: child,
          ),
  );
}

/// [AnimatedSize] that steps aside under reduced motion. A zero duration is
/// not enough: `RenderAnimatedSize` then re-dirties itself during its own
/// layout and throws in debug builds, so the child is laid out directly.
class AgamAnimatedSize extends StatelessWidget {
  const AgamAnimatedSize({
    super.key,
    required this.child,
    this.milliseconds = 280,
    this.curve = AgamMotion.easeOut,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final int milliseconds;
  final Curve curve;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(
          duration: Duration(milliseconds: milliseconds),
          curve: curve,
          alignment: alignment,
          child: child,
        );
}

/// One-shot entrance for list content: fades in and rises 10 px, staggered
/// by [order]. It plays the first time [play] is true and never repeats, so
/// switching tabs back and forth does not replay it.
class AgamReveal extends StatefulWidget {
  const AgamReveal({
    super.key,
    required this.child,
    this.order = 0,
    this.play = true,
  });

  final Widget child;
  final int order;
  final bool play;

  @override
  State<AgamReveal> createState() => _AgamRevealState();
}

class _AgamRevealState extends State<AgamReveal>
    with SingleTickerProviderStateMixin {
  static const _step = 45;
  static const _length = 340;

  late final _controller = AnimationController(vsync: this);
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    final delay = widget.order.clamp(0, 8) * _step;
    _controller.duration = Duration(milliseconds: _length + delay);
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay / (_length + delay), 1, curve: AgamMotion.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePlay();
  }

  @override
  void didUpdateWidget(covariant AgamReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybePlay();
  }

  void _maybePlay() {
    if (!widget.play || !_controller.isDismissed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    builder: (context, child) => Opacity(
      opacity: _curve.value,
      child: Transform.translate(
        offset: Offset(0, (1 - _curve.value) * 10),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

/// Preserves each tab's state/subscriptions while animating the newly active tab.
class AgamTabTransition extends StatefulWidget {
  const AgamTabTransition({
    super.key,
    required this.index,
    required this.child,
  });
  final int index;
  final Widget child;

  @override
  State<AgamTabTransition> createState() => _AgamTabTransitionState();
}

class _AgamTabTransitionState extends State<AgamTabTransition>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this, value: 1);

  @override
  void didUpdateWidget(covariant AgamTabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _animation.duration = AgamMotion.duration(context, 180);
      if (_animation.duration == Duration.zero) {
        _animation.value = 1;
      } else {
        _animation.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? widget.child
      : FadeThroughTransition(
          animation: _animation,
          secondaryAnimation: const AlwaysStoppedAnimation(0),
          fillColor: Colors.transparent,
          child: widget.child,
        );
}

/// Feedback only; the child's InkWell/button keeps gesture and semantic actions.
class AgamPressFeedback extends StatefulWidget {
  const AgamPressFeedback({super.key, required this.child});
  final Widget child;

  @override
  State<AgamPressFeedback> createState() => _AgamPressFeedbackState();
}

class _AgamPressFeedbackState extends State<AgamPressFeedback> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => _pressed = true),
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? .97 : 1,
      duration: AgamMotion.duration(context, 140),
      curve: AgamMotion.easeOut,
      child: widget.child,
    ),
  );
}
