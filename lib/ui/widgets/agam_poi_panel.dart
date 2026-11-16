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
