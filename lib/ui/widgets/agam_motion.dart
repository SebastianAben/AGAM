import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

abstract final class AgamMotion {
  static const easeOut = Cubic(0.23, 1, 0.32, 1);
  static const drawer = Cubic(0.32, 0.72, 0, 1);

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
