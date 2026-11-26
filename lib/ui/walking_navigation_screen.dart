import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../contracts/contracts.dart';
import 'widgets/agam_components.dart';
import 'widgets/agam_theme.dart';
import 'widgets/offline_campus_map.dart';

/// UI06. Cari & Rute owns the session and returns to UI07 on arrival.
class WalkingNavigationScreen extends StatefulWidget {
  const WalkingNavigationScreen({
    super.key,
    required this.services,
    required this.target,
    required this.onEnd,
  });

  final AppServices services;
  final NavigationTarget target;
  final Future<void> Function() onEnd;

  @override
  State<WalkingNavigationScreen> createState() =>
      _WalkingNavigationScreenState();
}

class _WalkingNavigationScreenState extends State<WalkingNavigationScreen> {
  final _map = GlobalKey<OfflineCampusMapState>();
  final _mapWindow = GlobalKey();
  bool _ending = false;

  Future<void> _end() async {
    if (_ending) return;
    setState(() => _ending = true);
    try {
      await widget.onEnd();
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  void _fit(List<GeoPoint> points) {
    final map = _map.currentState;
    final mapBox = _map.currentContext?.findRenderObject() as RenderBox?;
    final window = _mapWindow.currentContext?.findRenderObject() as RenderBox?;
    if (map == null || mapBox == null || window == null) return;
    // Leave room around the path and the destination marker's label.
    if (window.size.width <= 80 || window.size.height <= 56) {
      if (points.isNotEmpty) map.focusOn(points.first);
      return;
    }
    final origin =
        window.localToGlobal(Offset.zero) - mapBox.localToGlobal(Offset.zero);
    map.fitPoints(
      points,
      padding: EdgeInsets.fromLTRB(
        origin.dx + 40,
        origin.dy + 22,
        mapBox.size.width - origin.dx - window.size.width + 40,
        mapBox.size.height - origin.dy - window.size.height + 34,
      ),
    );
  }

  void _fitStart(GeoPoint? position, List<GeoPoint> path) {
    final points = <GeoPoint>[?position];
    var distance = 0.0;
    for (var i = 0; i < path.length; i++) {
      if (i > 0) distance += path[i - 1].distanceTo(path[i]);
      // Fit the start of longer walks at a legible zoom.
      if (distance > 180 && i > 1) break;
      points.add(path[i]);
    }
    _fit(points);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _end();
    },
    child: Scaffold(
      body: StreamBuilder<NavigationState>(
        stream: widget.services.navigation.state,
        initialData: widget.services.navigation.current,
        builder: (context, snapshot) {
          final state = snapshot.requireData;
          final target = state.target ?? widget.target;
          final path = switch (state.status) {
            NavigationStatus.onRoute ||
            NavigationStatus.offRoute ||
            NavigationStatus.rerouting =>
              state.route?.path ?? const <GeoPoint>[],
            _ => const <GeoPoint>[],
          };
          return StreamBuilder<LocationFix>(
            stream: widget.services.location.positions,
            initialData: widget.services.location.lastFix,
            builder: (context, snapshot) {
              final fix = snapshot.data;
              final position = fix?.position;
              return Stack(
                fit: StackFit.expand,
                children: [
                  OfflineCampusMap(
                    key: _map,
                    config: widget.services.map,
                    pois: const [],
                    onSelectPoi: (_) {},
                    userPosition: position,
                    userAccuracyM: fix?.accuracyM,
                    initialFocus: position ?? path.firstOrNull,
                    onMapReady: () => _fitStart(position, path),
                    routePath: path,
                    highlight: MapHighlight(
                      point: path.lastOrNull ?? target.point,
                      label: target.name,
                      icon: target.kind == NavigationTargetKind.poi
                          ? Icons.apartment_rounded
                          : Icons.place_rounded,
                    ),
                    attributionPadding: null,
                  ),
                  SafeArea(
                    minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InstructionPanel(state: state),
                        Expanded(child: SizedBox.expand(key: _mapWindow)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Expanded(
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: MapAttribution(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            DecoratedBox(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: AgamShadows.floating,
                              ),
                              child: IconButton(
                                tooltip: 'Pusatkan lokasi saya',
                                icon: const Icon(Icons.my_location_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AgamColors.brand,
                                  fixedSize: const Size.square(48),
                                ),
                                onPressed: position == null
                                    ? null
                                    : () => _fit([position]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _RouteSummary(
                          target: target,
                          state: state,
                          onEnd: _ending ? null : _end,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    ),
  );
}

class _InstructionPanel extends StatelessWidget {
  const _InstructionPanel({required this.state});

  final NavigationState state;

  @override
  Widget build(BuildContext context) {
    final step = state.currentStep;
    final icon = switch (step?.maneuver) {
      Maneuver.turnLeft => Icons.turn_left_rounded,
      Maneuver.turnRight => Icons.turn_right_rounded,
      Maneuver.slightLeft => Icons.turn_slight_left_rounded,
      Maneuver.slightRight => Icons.turn_slight_right_rounded,
      Maneuver.depart || Maneuver.straight => Icons.straight_rounded,
      Maneuver.arrive => Icons.flag_rounded,
      null => Icons.directions_walk_rounded,
    };
    final instruction = switch (state.status) {
      NavigationStatus.offRoute => 'Anda berada di luar jalur.',
      NavigationStatus.rerouting => 'Menghitung ulang rute…',
      NavigationStatus.error => 'Rute tidak tersedia dari posisi saat ini.',
      _ => step?.instruction ?? 'Menyiapkan arahan…',
    };
    return AgamGround(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AgamIconTile(
            icon: icon,
            size: 48,
            foreground: Colors.white,
            background: Colors.white.withValues(alpha: .14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                instruction,
                style: AgamText.headline.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    required this.target,
    required this.state,
    required this.onEnd,
  });

  final NavigationTarget target;
  final NavigationState state;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final distance = state.remainingDistanceM;
    final eta = state.remainingEta;
    final minutes = eta == null
        ? null
        : math.max(1, (eta.inSeconds / 60).ceil());
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AgamRadius.card),
        boxShadow: AgamShadows.floating,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(target.name, style: AgamText.title),
            const SizedBox(height: 4),
            Text(
              'Sisa ${distance == null ? '—' : '${distance.round()} m'}'
              ' · ${minutes == null ? '—' : '~$minutes menit'}',
              style: AgamText.label.copyWith(color: AgamColors.brand),
            ),
            if (target.isPlaceholderPoint) ...[
              const SizedBox(height: 4),
              const Text('Tujuan perkiraan', style: AgamText.caption),
            ],
            const SizedBox(height: 10),
            AgamTonalButton(
              label: 'Akhiri rute',
              icon: Icons.close_rounded,
              onPressed: onEnd,
              foreground: AgamColors.danger,
              background: AgamColors.dangerTint,
            ),
          ],
        ),
      ),
    );
  }
}
