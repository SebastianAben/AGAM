import 'package:flutter/material.dart';

import 'agam_motion.dart';

typedef PoiPanelBuilder = Widget Function(
  BuildContext context,
  ScrollController scroll,
  bool expanded,
  VoidCallback toggle,
  Widget handle,
);

/// The sheet and scrollbar share the native draggable sheet's scroll position.
class AgamPoiPanel extends StatefulWidget {
  const AgamPoiPanel({super.key, required this.builder});
  final PoiPanelBuilder builder;

  @override
  State<AgamPoiPanel> createState() => _AgamPoiPanelState();
}

class _AgamPoiPanelState extends State<AgamPoiPanel> {
  final _sheet = DraggableScrollableController();
  bool _expanded = false;

  void _move(double size) {
    if (!_sheet.isAttached) return;
    final duration = AgamMotion.duration(context);
    if (duration == Duration.zero) {
      _sheet.jumpTo(size);
    } else {
      _sheet.animateTo(size, duration: duration, curve: AgamMotion.drawer);
    }
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            final expanded = notification.extent > .75;
            if (_expanded != expanded) setState(() => _expanded = expanded);
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _sheet,
            initialChildSize: .65,
            minChildSize: .35,
            maxChildSize: .9,
            snap: !MediaQuery.disableAnimationsOf(context),
            snapSizes: const [.65],
            shouldCloseOnMinExtent: false,
            builder: (context, scroll) {
              void toggle() => _move(_expanded ? .65 : .9);
              final handle = Semantics(
                button: true,
                label: _expanded ? 'Ciutkan panel POI' : 'Perluas panel POI',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: toggle,
                  onVerticalDragUpdate: (details) {
                    if (!_sheet.isAttached) return;
                    _sheet.jumpTo(
                      (_sheet.size - details.delta.dy / constraints.maxHeight)
                          .clamp(.35, .9),
                    );
                  },
                  onVerticalDragEnd: (details) {
                    if (!_sheet.isAttached) return;
                    final velocity = details.primaryVelocity ?? 0;
                    final target = velocity < -500
                        ? .9
                        : velocity > 500
                        ? .35
                        : [.35, .65, .9].reduce(
                            (a, b) =>
                                (a - _sheet.size).abs() <
                                    (b - _sheet.size).abs()
                                ? a
                                : b,
                          );
                    _move(target);
                  },
                  child: SizedBox(
                    height: 28,
                    width: double.infinity,
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC4C9D9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              return widget.builder(context, scroll, _expanded, toggle, handle);
            },
          ),
        ),
  );
}

/// Softens the bottom edge of the panel's scroll body while more content
/// sits below it. At the mid snap the sheet often ends inside a row of
/// facility chips; a short fade turns that half-cut row into an obvious
/// "scroll for more" instead of a clipped edge. The fade leaves once the
/// end is reached, so the last row is never dimmed.
///
/// Place it between the [Scrollbar] and the scroll view, so the thumb
/// itself is not faded.
class AgamScrollEdgeFade extends StatefulWidget {
  const AgamScrollEdgeFade({super.key, required this.child, this.extent = 36});

  final Widget child;

  /// Height of the fade, in logical pixels.
  final double extent;

  @override
  State<AgamScrollEdgeFade> createState() => _AgamScrollEdgeFadeState();
}

class _AgamScrollEdgeFadeState extends State<AgamScrollEdgeFade> {
  bool _moreBelow = false;

  bool _update(ScrollMetrics metrics, int depth) {
    if (depth != 0 || metrics.axis != Axis.vertical) return false;
    final moreBelow = metrics.extentAfter > .5;
    if (moreBelow != _moreBelow && mounted) {
      setState(() => _moreBelow = moreBelow);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => _update(n.metrics, n.depth),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _update(n.metrics, n.depth),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: _moreBelow ? 1 : 0),
            // Opacity only; with reduced motion it switches at once.
            duration: AgamMotion.duration(context, 160),
            curve: AgamMotion.easeOut,
            // The mask stays in the tree at every strength, so the scroll
            // view keeps its state when the fade comes and goes.
            builder: (context, strength, child) => ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) {
                final start = bounds.height <= 0
                    ? 1.0
                    : (1 - widget.extent / bounds.height).clamp(0.0, 1.0);
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [start, 1],
                  colors: [
                    const Color(0xFFFFFFFF),
                    Color.fromRGBO(255, 255, 255, 1 - strength),
                  ],
                ).createShader(bounds);
              },
              child: child,
            ),
            child: widget.child,
          ),
        ),
      );
}
