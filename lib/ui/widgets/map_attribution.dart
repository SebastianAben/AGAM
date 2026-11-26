import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'agam_motion.dart';
import 'agam_theme.dart';

/// The required OpenStreetMap and OpenMapTiles credit.
///
/// It shows in full when it appears, then folds into an "ⓘ" button after
/// [visibleFor] or on the first touch of the map, whichever comes first
/// (OSMF Attribution Guidelines, PRD §14). The button brings the full credit
/// back, which then folds again under the same rules. The countdown only
/// runs while the credit is on screen (tickers enabled), so a tab or route
/// hidden underneath does not use it up.
class MapAttribution extends StatefulWidget {
  const MapAttribution({super.key});

  static const visibleFor = Duration(seconds: 5);

  /// Called by [OfflineCampusMap] when a finger touches the map (pan, zoom
  /// or tap). The credit is often placed beside the map rather than inside
  /// it, so the signal is shared instead of passed down the tree.
  static void notifyMapTouched() => _mapTouches.value++;

  static final _mapTouches = ValueNotifier<int>(0);

  @override
  State<MapAttribution> createState() => _MapAttributionState();
}

class _MapAttributionState extends State<MapAttribution> {
  bool _expanded = true;
  bool _onScreen = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    MapAttribution._mapTouches.addListener(_collapse);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onScreen = TickerMode.valuesOf(context).enabled;
    if (onScreen == _onScreen) return;
    _onScreen = onScreen;
    _onScreen ? _startTimer() : _timer?.cancel();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_expanded && _onScreen) {
      _timer = Timer(MapAttribution.visibleFor, _collapse);
    }
  }

  void _collapse() {
    _timer?.cancel();
    if (mounted && _expanded) setState(() => _expanded = false);
  }

  void _expand() {
    setState(() => _expanded = true);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    MapAttribution._mapTouches.removeListener(_collapse);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AgamAnimatedSize(
    milliseconds: 240,
    alignment: Alignment.bottomLeft,
    child: AnimatedSwitcher(
      duration: AgamMotion.duration(context, 240),
      switchInCurve: AgamMotion.easeOut,
      switchOutCurve: AgamMotion.easeOut,
      // The outgoing state is laid out loosely so it never holds the size
      // open; AgamAnimatedSize clips it while the box shrinks or grows.
      layoutBuilder: (current, previous) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomLeft,
        children: [
          for (final outgoing in previous)
            Positioned(
              left: 0,
              bottom: 0,
              child: ExcludeSemantics(child: IgnorePointer(child: outgoing)),
            ),
          ?current,
        ],
      ),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _expanded
          ? _Credits(key: const ValueKey('credits'))
          : _InfoButton(key: const ValueKey('info'), onPressed: _expand),
    ),
  );
}

class _InfoButton extends StatelessWidget {
  const _InfoButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Tampilkan atribusi peta',
    onPressed: onPressed,
    icon: const Icon(Icons.info_outline_rounded, size: 18),
    // A 30 px badge like the credit pill, inside a 48 px touch target.
    style: IconButton.styleFrom(
      foregroundColor: AgamColors.ink,
      backgroundColor: Colors.white.withValues(alpha: .88),
      fixedSize: const Size.square(30),
      minimumSize: const Size.square(30),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.padded,
    ),
  );
}

class _Credits extends StatelessWidget {
  const _Credits({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .88),
      borderRadius: BorderRadius.circular(10),
    ),
    // Wraps to a second line rather than overflow on narrow screens or
    // with large system text.
    child: Wrap(
      children: [
        _credit(
          context,
          '© OpenStreetMap contributors (ODbL)',
          'https://www.openstreetmap.org/copyright',
        ),
        _credit(context, '© OpenMapTiles', 'https://openmaptiles.org/'),
      ],
    ),
  );

  Widget _credit(BuildContext context, String label, String url) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: AgamColors.ink,
      textStyle: const TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        fontFamily: 'PlusJakartaSans',
      ),
      minimumSize: const Size(0, 26),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    onPressed: () async {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tautan atribusi tidak dapat dibuka.')),
        );
      }
    },
    child: Text(label),
  );
}
