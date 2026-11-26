import 'package:flutter/material.dart';

import '../../contracts/models/content.dart';
import '../../contracts/models/discovery.dart';
import '../../contracts/models/geo.dart';
import 'agam_components.dart';
import 'agam_motion.dart';
import 'agam_theme.dart';
import 'facility_labels.dart';

/// One recommended POI with why it is offered and how far it is.
class RecommendedPoi {
  const RecommendedPoi({
    required this.poi,
    required this.reason,
    required this.distanceM,
  });

  final Poi poi;
  final String reason;

  /// Straight-line distance from where the recommendation was asked.
  final double distanceM;
}

/// What [RecommendationCard] shows, resolved once when the result arrives.
///
/// Only names, reasons and rounded distances are kept; the position the
/// recommendation was asked from is not stored (PRD A01).
class RecommendationView {
  const RecommendationView({
    required this.pois,
    required this.facilities,
    this.origin,
  });

  /// Resolves [result]'s IDs against [pois], dropping IDs not in the
  /// dataset. [origin] names the place distances are measured from when it
  /// is not the user's own position (e.g. the POI that was just closed).
  factory RecommendationView.resolve(
    Recommendation result, {
    required List<Poi> pois,
    required GeoPoint from,
    required bool trailActive,
    String? origin,
  }) {
    final byId = {for (final poi in pois) poi.id: poi};
    final resolved = [for (final id in result.poiIds) ?byId[id]];
    return RecommendationView(
      pois: [
        for (var index = 0; index < resolved.length; index++)
          RecommendedPoi(
            poi: resolved[index],
            reason: switch ((trailActive, index)) {
              (true, 0) => 'Berikutnya di trail',
              (true, _) => 'Urutan trail',
              (false, 0) => 'Terdekat',
              (false, _) => 'Belum dikunjungi',
            },
            distanceM: from.distanceTo(resolved[index].position),
          ),
      ],
      facilities: result.nearbyFacilities.take(2).toList(),
      origin: origin,
    );
  }

  final List<RecommendedPoi> pois;
  final List<FacilityDistance> facilities;
  final String? origin;

  bool get isEmpty => pois.isEmpty && facilities.isEmpty;
}

/// Rounded, approximate straight-line distance; never a walking distance.
String approximateDistance(double meters) {
  if (meters < 1000) {
    final rounded = ((meters / 10).round() * 10).clamp(10, 990);
    return '± $rounded m';
  }
  final km = (meters / 1000).toStringAsFixed(1).replaceAll('.', ',');
  return '± $km km';
}

/// UI07 "Lanjut ke mana?": 1–3 next POIs, each routed with one tap, and the
/// nearest facilities (F07).
///
/// Purely presentational: the screens ask `RecommendationService` and pass
/// the resolved [view]. Nothing here is logged; a recommendation appears
/// right after an arrival or a closed card, so `featureUsed` would date the
/// visit (PRD §15.5, rules §5.1).
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.view,
    required this.onRoute,
    this.routeAvailable = true,
    this.onDismiss,
    this.floating = false,
  });

  static const title = 'Lanjut ke mana?';
  static const emptyMessage =
      'Belum ada POI lain untuk direkomendasikan saat ini.';

  final RecommendationView view;
  final ValueChanged<Poi> onRoute;
  final bool routeAvailable;

  /// Shows a "Tutup" pill in the header; used where the card floats over
  /// the map.
  final VoidCallback? onDismiss;

  /// Over the map the card takes the floating shadow of map controls.
  final bool floating;

  String _distance(double meters) {
    final origin = view.origin;
    final text = approximateDistance(meters);
    return origin == null ? text : '$text dari $origin';
  }

  @override
  Widget build(BuildContext context) {
    final dismiss = onDismiss;
    return Container(
      key: const ValueKey('recommendation-card'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AgamRadius.card),
        boxShadow: floating ? AgamShadows.floating : AgamShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                dismiss == null ? 16 : 12,
                12,
                dismiss == null ? 4 : 0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: AgamText.headline),
                    ),
                  ),
                  if (dismiss != null)
                    AgamTextPill.outlined(
                      key: const ValueKey('recommendation-dismiss'),
                      label: 'Tutup',
                      semanticLabel: 'Tutup rekomendasi',
                      onPressed: dismiss,
                    ),
                ],
              ),
            ),
            if (view.pois.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 6, 18, 14),
                child: Text(emptyMessage, style: AgamText.bodySmall),
              )
            else
              for (final item in view.pois)
                AgamListRow(
                  key: ValueKey('recommendation-poi-${item.poi.id}'),
                  icon: Icons.apartment_rounded,
                  title: item.poi.name,
                  subtitle: '${item.reason} · ${_distance(item.distanceM)}',
                  trailing: SizedBox(
                    width: 92,
                    child: AgamRouteButton(
                      key: ValueKey('recommendation-route-${item.poi.id}'),
                      available: routeAvailable,
                      onPressed: () => onRoute(item.poi),
                      height: 40,
                      padding: 10,
                    ),
                  ),
                ),
            if (view.facilities.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fasilitas terdekat', style: AgamText.caption),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in view.facilities)
                          AgamPill(
                            '${item.facility.name} · '
                            '${_distance(item.distanceM)}',
                            key: ValueKey(
                              'recommendation-facility-${item.facility.id}',
                            ),
                            icon: facilityIcon(item.facility.category),
                            tone: AgamColors.teal,
                          ),
                      ],
                    ),
                  ],
                ),
              )
            else if (view.pois.isNotEmpty)
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// Brings a recommendation in and out without a jump: the space opens with
/// [AgamAnimatedSize] while the card fades in and rises 8 px over 220 ms
/// ([AgamMotion.easeOut]); it leaves faster, in 150 ms, before its space
/// closes. It also enters when it is built together with the arrival card,
/// so the two read as one arrival. Under reduced motion it appears and goes
/// at once. [child] `null` means nothing to show.
class RecommendationPresence extends StatefulWidget {
  const RecommendationPresence({super.key, required this.child});

  final Widget? child;

  @override
  State<RecommendationPresence> createState() => _RecommendationPresenceState();
}

class _RecommendationPresenceState extends State<RecommendationPresence>
    with SingleTickerProviderStateMixin {
  static const _rise = 8.0;

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 150),
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: AgamMotion.easeOut,
    // Played backwards, so the flipped curve leaves quickly too.
    reverseCurve: AgamMotion.easeOut.flipped,
  );

  /// The card on screen; kept while it fades out after [widget.child] left.
  Widget? _shown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant RecommendationPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final child = widget.child;
    if (child != null) {
      _shown = child;
      if (reduce) {
        _controller.value = 1;
      } else if (_controller.status != AnimationStatus.completed &&
          _controller.status != AnimationStatus.forward) {
        _controller.forward();
      }
    } else if (_shown != null) {
      if (reduce) {
        _controller.value = 0;
        _shown = null;
      } else if (_controller.status != AnimationStatus.reverse) {
        _controller.reverse().then((_) {
          if (mounted && widget.child == null) setState(() => _shown = null);
        });
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return AgamAnimatedSize(
      milliseconds: 220,
      alignment: Alignment.topCenter,
      child: shown == null
          ? const SizedBox(width: double.infinity)
          : MediaQuery.disableAnimationsOf(context)
          ? shown
          : AnimatedBuilder(
              animation: _curve,
              child: shown,
              builder: (context, child) => Opacity(
                opacity: _curve.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - _curve.value) * _rise),
                  child: child,
                ),
              ),
            ),
    );
  }
}
