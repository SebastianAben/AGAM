import 'package:flutter/material.dart';

/// Keeps scrollable content within its bounds without a stretch or glow effect.
class AgamScrollBehavior extends MaterialScrollBehavior {
  const AgamScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
