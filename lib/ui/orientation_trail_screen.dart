import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../contracts/app_services.dart';
import '../contracts/models/content.dart';
import '../contracts/models/discovery.dart';
import '../contracts/models/navigation.dart';
import '../contracts/models/session.dart';
import 'poi_detail_screen.dart';
import 'widgets/agam_components.dart';
import 'widgets/agam_motion.dart';
import 'widgets/agam_theme.dart';

/// UI08 Orientation Trail. The route action starts UI06; UI07 recommendation
/// results remain separate.
class OrientationTrailScreen extends StatefulWidget {
  const OrientationTrailScreen({
    super.key,
    required this.services,
    this.embedded = false,
    this.isActive = true,
    this.internalDemo = false,
    this.onTabSelected,
  });

  final AppServices services;
  final bool embedded;

  /// Entrance motion waits until the tab is first shown.
  final bool isActive;
  final bool internalDemo;
  final ValueChanged<int>? onTabSelected;

  @override
  State<OrientationTrailScreen> createState() => _OrientationTrailScreenState();
}

class _OrientationTrailScreenState extends State<OrientationTrailScreen> {
  late TrailProgress _progress;
  List<Poi> _pois = const [];
  int _filter = 0;
  bool _busy = false;
  String? _detailPoiId;
  NavigationState _navigation = const NavigationState.idle();
  final _subscriptions = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _progress = widget.internalDemo
        ? const TrailProgress(order: [], visited: {}, active: false)
        : widget.services.trail.current;
    _subscriptions.add(
      widget.services.pois.watchPois().listen((pois) {
        if (!mounted) return;
        setState(() {
          _pois = pois;
          if (widget.internalDemo) {
            // Urutan repository hanya untuk tata letak contoh, bukan trail resmi.
            _progress = TrailProgress(
              order: pois.map((poi) => poi.id).toList(),
              visited: const {},
              active: false,
            );
          }
        });
      }),
    );
    if (!widget.internalDemo) {
      _subscriptions.add(
        widget.services.trail.progress.listen((progress) {
          if (mounted) setState(() => _progress = progress);
        }),
      );
      _subscriptions.add(
        widget.services.navigation.state.listen((state) {
          if (mounted) setState(() => _navigation = state);
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  List<Poi> get _orderedPois => [
    for (final id in _progress.order)
      for (final poi in _pois)
        if (poi.id == id) poi,
  ];

  List<Poi> get _visiblePois {
    final ordered = _orderedPois;
    if (_filter == 1) {
      return ordered
          .where((poi) => !_progress.visited.contains(poi.id))
          .toList();
    }
    if (_filter == 2) {
      return ordered
          .where((poi) => _progress.visited.contains(poi.id))
          .toList();
    }
    return ordered;
  }

  Poi? _poiById(String? id) {
    if (id == null) return null;
    for (final poi in _orderedPois) {
      if (poi.id == id) return poi;
    }
    return null;
  }

  Poi? get _nextPoi => _poiById(_progress.nextPoiId);

  bool _hasArrivedAt(Poi poi) =>
      _navigation.target?.id == poi.id &&
      _navigation.status == NavigationStatus.arrived;

  Future<void> _continueTrail([Poi? destination]) async {
    if (widget.internalDemo) {
      _message('Trail belum tersedia.');
      return;
    }
    if (_busy) return;
    final targetPoi = destination ?? _nextPoi;
    if (targetPoi == null) {
      _message('Semua POI pada daftar contoh sudah selesai.');
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.services.trail.start();
      await widget.services.session.start(SessionMode.trail);
      await widget.services.navigation.start(NavigationTarget.poi(targetPoi));
      if (mounted) {
        _message(
          targetPoi.hasSurveyedEntrance
              ? 'Rute contoh menuju ${targetPoi.name} dimulai.'
              : 'Titik masuk ${targetPoi.name} belum disurvei. Rute contoh memakai titik tengah gedung.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endTrail() async {
    if (widget.internalDemo) return;
    await widget.services.navigation.stop();
    await widget.services.session.end();
    await widget.services.trail.stop();
  }

  Future<void> _openPoiDetails(Poi poi) async {
    await Navigator.of(context).push<void>(
      AgamMotion.route(
        (_) => PoiDetailScreen(
          poi: poi,
          audio: widget.services.audio,
          settings: widget.services.settings,
          checkedIn: _progress.visited.contains(poi.id),
          navigationAvailable: !widget.internalDemo,
          onNavigate: () => _continueTrail(poi),
        ),
      ),
    );
  }

  void _showCheckInStatus(Poi poi, {required bool checkedIn}) {
    _message(
      widget.internalDemo
          ? 'Check-in belum tersedia.'
          : checkedIn
          ? 'Check-in ${poi.name} sudah tercatat otomatis.'
          : 'Check-in akan tercatat otomatis saat lokasi terdeteksi.',
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _progress.total;
    final completed = _progress.visitedCount;
    final percent = total == 0 ? 0.0 : completed / total;
    final nextPoi = _nextPoi;
    final visible = _visiblePois;
    final play = widget.isActive;

    return Scaffold(
      backgroundColor: AgamColors.canvas,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              clipBehavior: Clip.hardEdge,
              slivers: [
                SliverSafeArea(
                  top: !widget.embedded,
                  bottom: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    sliver: SliverList.list(
                      children: [
                        AgamReveal(
                          play: play,
                          child: _TrailHero(
                            progress: _progress,
                            percent: percent,
                            play: play,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AgamReveal(
                          order: 1,
                          play: play,
                          child: _BadgeCard(
                            progress: _progress,
                            percent: percent,
                          ),
                        ),
                        const SizedBox(height: 28),
                        AgamReveal(
                          order: 2,
                          play: play,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AgamSegmented(
                                labels: [
                                  'Semua (${_orderedPois.length})',
                                  'Belum (${_orderedPois.length - completed})',
                                  'Selesai ($completed)',
                                ],
                                selected: _filter,
                                onChanged: (filter) =>
                                    setState(() => _filter = filter),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (visible.isEmpty)
                          AgamReveal(
                            order: 3,
                            play: play,
                            child: AgamCard(
                              child: Text(
                                _filter == 2
                                    ? 'Belum ada gedung yang selesai.'
                                    : 'Belum ada gedung di daftar ini.',
                                style: AgamText.bodySmall,
                              ),
                            ),
                          ),
                        for (var i = 0; i < visible.length; i++)
                          AgamReveal(
                            order: 3 + i,
                            play: play,
                            child: _TrailStep(
                              index: _progress.order.indexOf(visible[i].id) + 1,
                              poi: visible[i],
                              last: i == visible.length - 1,
                              done: _progress.visited.contains(visible[i].id),
                              isArrived: _hasArrivedAt(visible[i]),
                              isNext:
                                  !widget.internalDemo &&
                                  visible[i].id == _progress.nextPoiId,
                              isActive: _progress.active,
                              expanded: _detailPoiId == visible[i].id,
                              navigationState: _navigation,
                              onExpand: () => setState(
                                () =>
                                    _detailPoiId = _detailPoiId == visible[i].id
                                    ? null
                                    : visible[i].id,
                              ),
                              onRoute: widget.internalDemo
                                  ? null
                                  : () => _continueTrail(visible[i]),
                              onCheckIn: () => _showCheckInStatus(
                                visible[i],
                                checkedIn: _progress.visited.contains(
                                  visible[i].id,
                                ),
                              ),
                              onDetails: () => _openPoiDetails(visible[i]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _TrailBottomArea(
            nextPoi: widget.internalDemo ? null : nextPoi,
            internalDemo: widget.internalDemo,
            busy: _busy,
            isActive: _progress.active,
            navigation: _navigation,
            onContinue: _continueTrail,
            onEnd: _endTrail,
          ),
        ],
      ),
    );
  }
}

class _TrailHero extends StatelessWidget {
  const _TrailHero({
    required this.progress,
    required this.percent,
    required this.play,
  });

  final TrailProgress progress;
  final double percent;
  final bool play;

  @override
  Widget build(BuildContext context) {
    final count = progress.visitedCount;
    final total = progress.total;
    return AgamGround(
      colors: const [AgamColors.forest, AgamColors.teal],
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Orientation Trail',
              style: AgamText.display.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          _ProgressRing(
            progress: play ? percent : 0,
            count: count,
            total: total,
          ),
        ],
      ),
    );
  }
}

/// The ring fills once from zero when the tab is first shown, then follows
/// progress changes with the same curve.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.progress,
    required this.count,
    required this.total,
  });

  final double progress;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: progress),
    duration: AgamMotion.duration(context, 900),
    curve: AgamMotion.easeOut,
    builder: (context, value, _) => SizedBox.square(
      dimension: 86,
      child: CustomPaint(
        painter: _RingPainter(value),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '$count/$total',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: .18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (value <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * value.clamp(0, 1),
      false,
      Paint()
        ..color = AgamColors.mint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.value != value;
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.progress, required this.percent});

  final TrailProgress progress;
  final double percent;

  @override
  Widget build(BuildContext context) => AgamCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        AnimatedContainer(
          duration: AgamMotion.duration(context, 300),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: progress.isComplete
                  ? const [AgamColors.cyan, AgamColors.brand]
                  : const [AgamColors.tint, AgamColors.tint],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.workspace_premium_rounded,
            size: 30,
            color: progress.isComplete ? Colors.white : AgamColors.brand,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lencana Penjelajah Ganesha', style: AgamText.label),
              const SizedBox(height: 3),
              Text(
                progress.isComplete
                    ? 'Trail selesai — lencana terbuka.'
                    : 'Kunjungi semua gedung untuk membukanya.',
                style: AgamText.caption,
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: percent),
                  duration: AgamMotion.duration(context, 900),
                  curve: AgamMotion.easeOut,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: AgamColors.fill,
                    color: AgamColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// One stop on the trail: a numbered node on a vertical rail and a card.
class _TrailStep extends StatelessWidget {
  const _TrailStep({
    required this.index,
    required this.poi,
    required this.last,
    required this.done,
    required this.isArrived,
    required this.isNext,
    required this.isActive,
    required this.expanded,
    required this.navigationState,
    required this.onExpand,
    required this.onRoute,
    required this.onCheckIn,
    required this.onDetails,
  });

  final int index;
  final Poi poi;
  final bool last;
  final bool done;
  final bool isArrived;
  final bool isNext;
  final bool isActive;
  final bool expanded;
  final NavigationState navigationState;
  final VoidCallback onExpand;
  final VoidCallback? onRoute;
  final VoidCallback onCheckIn;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final routing =
        navigationState.target?.id == poi.id &&
        navigationState.status != NavigationStatus.idle;
    final contentReady = poi.metadata.approved && !poi.metadata.isPlaceholder;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                const SizedBox(height: 16),
                _StepNode(index: index, done: done, isNext: isNext),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: done ? AgamColors.success : AgamColors.line,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 12),
              child: AnimatedContainer(
                duration: AgamMotion.duration(context, 220),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AgamRadius.tile + 2),
                  border: Border.all(
                    color: isNext ? AgamColors.cyan : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: AgamShadows.card,
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onExpand,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  poi.name,
                                  style: AgamText.label.copyWith(fontSize: 15),
                                ),
                              ),
                              // The node already shows the step; only the
                              // states worth acting on get a word.
                              if (done || isNext) ...[
                                const SizedBox(width: 8),
                                AgamPill(
                                  done ? 'Selesai' : 'Berikutnya',
                                  tone: done
                                      ? AgamColors.success
                                      : AgamColors.brand,
                                ),
                              ],
                            ],
                          ),
                          if (contentReady) ...[
                            const SizedBox(height: 8),
                            AnimatedSize(
                              duration: AgamMotion.duration(context, 240),
                              curve: AgamMotion.easeOut,
                              alignment: Alignment.topCenter,
                              child: Text(
                                poi.description,
                                maxLines: expanded ? null : 2,
                                overflow: expanded
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                                style: AgamText.bodySmall,
                              ),
                            ),
                          ],
                          if (done || isArrived) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: AgamTonalButton(
                                    onPressed: onCheckIn,
                                    height: 44,
                                    icon: Icons.check_circle_rounded,
                                    foreground: AgamColors.success,
                                    background: AgamColors.successTint,
                                    label: 'Check-in',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: AgamTonalButton(
                                    onPressed: onDetails,
                                    height: 44,
                                    icon: Icons.info_outline_rounded,
                                    label: 'Detail',
                                  ),
                                ),
                              ],
                            ),
                          ] else if (isNext) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: AgamPrimaryButton(
                                    onPressed: onRoute,
                                    height: 44,
                                    icon: routing
                                        ? Icons.navigation_rounded
                                        : Icons.directions_rounded,
                                    label: routing
                                        ? 'Sedang menuju'
                                        : isActive
                                        ? 'Lanjutkan rute'
                                        : 'Rute',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AgamTonalButton(
                                  onPressed: onDetails,
                                  height: 44,
                                  label: 'Detail',
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.done,
    required this.isNext,
  });

  final int index;
  final bool done;
  final bool isNext;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AgamMotion.duration(context, 240),
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: done
          ? AgamColors.success
          : isNext
          ? AgamColors.brand
          : Colors.white,
      shape: BoxShape.circle,
      border: Border.all(
        color: done || isNext ? Colors.transparent : AgamColors.line,
        width: 2,
      ),
      boxShadow: isNext
          ? [
              BoxShadow(
                color: AgamColors.cyan.withValues(alpha: .45),
                spreadRadius: 4,
              ),
            ]
          : const [],
    ),
    child: Center(
      child: done
          ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
          : Text(
              '$index',
              style: TextStyle(
                color: isNext ? Colors.white : AgamColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
    ),
  );
}

class _TrailBottomArea extends StatelessWidget {
  const _TrailBottomArea({
    required this.nextPoi,
    required this.internalDemo,
    required this.busy,
    required this.isActive,
    required this.navigation,
    required this.onContinue,
    required this.onEnd,
  });

  final Poi? nextPoi;
  final bool internalDemo;
  final bool busy;
  final bool isActive;
  final NavigationState navigation;
  final Future<void> Function([Poi?]) onContinue;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    final buttonText = isActive
        ? 'Lanjutkan Trail: ${nextPoi?.name ?? 'selesai'}'
        : nextPoi == null
        ? 'Mulai Trail'
        : 'Mulai Trail: ${nextPoi!.name}';
    final remaining = navigation.remainingDistanceM;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F0B1F44),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (internalDemo && nextPoi == null) ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AgamColors.subtle,
                  ),
                  SizedBox(width: 6),
                  Text('Urutan trail belum tersedia.', style: AgamText.caption),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: AgamPrimaryButton(
                    onPressed: busy || nextPoi == null
                        ? null
                        : () => onContinue(),
                    busy: busy,
                    icon: Icons.flag_rounded,
                    label: remaining == null
                        ? buttonText
                        : '$buttonText · ${remaining.round()} m',
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'Akhiri Trail',
                    child: AgamPressFeedback(
                      child: Material(
                        color: AgamColors.dangerTint,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onEnd,
                          customBorder: const CircleBorder(),
                          child: const SizedBox.square(
                            dimension: 54,
                            child: Icon(
                              Icons.stop_rounded,
                              color: AgamColors.danger,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
