import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../contracts/app_services.dart';
import '../contracts/models/content.dart';
import '../contracts/models/discovery.dart';
import '../contracts/models/navigation.dart';
import '../contracts/models/location.dart';
import '../contracts/models/session.dart';
import '../logic/trail/device_trail_service.dart';
import 'poi_detail_screen.dart';
import 'walking_navigation_screen.dart';
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
    this.onTabSelected,
  });

  final AppServices services;
  final bool embedded;

  /// Entrance motion waits until the tab is first shown.
  final bool isActive;
  final ValueChanged<int>? onTabSelected;

  @override
  State<OrientationTrailScreen> createState() => _OrientationTrailScreenState();
}

class _OrientationTrailScreenState extends State<OrientationTrailScreen>
    with WidgetsBindingObserver {
  late TrailProgress _progress;
  List<Poi> _pois = const [];
  int _filter = 0;
  bool _busy = false;
  String? _detailPoiId;
  NavigationState _navigation = const NavigationState.idle();
  final _subscriptions = <StreamSubscription<dynamic>>[];

  /// Before the first start the nearest stop is previewed from a fix held
  /// only in memory while this tab is shown (PRD §6, rules §5.1): never
  /// stored, logged or sent, and dropped as soon as the read stops.
  StreamSubscription<LocationFix>? _warmFix;
  LocationFix? _fix;
  bool _appVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appVisible = _isVisible(WidgetsBinding.instance.lifecycleState);
    _progress = widget.services.trail.current;
    _subscriptions.add(
      widget.services.pois.watchPois().listen((pois) {
        if (!mounted) return;
        setState(() => _pois = pois);
      }),
    );
    _subscriptions.add(
      widget.services.trail.progress.listen(
        (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
          _syncWarmFix();
        },
        onError: (Object _) {
          if (mounted) _message('Progres trail belum dapat diperbarui.');
        },
      ),
    );
    _subscriptions.add(
      widget.services.navigation.state.listen((state) {
        if (mounted) setState(() => _navigation = state);
      }),
    );
    _syncWarmFix();
  }

  @override
  void didUpdateWidget(OrientationTrailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) _syncWarmFix();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = _isVisible(state);
    _syncWarmFix();
  }

  static bool _isVisible(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _warmFix?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  /// Location is read only while the device trail can still pick its
  /// nearest start: the tab shown, the app visible, no trail running and no
  /// stop checked in yet.
  bool get _wantsWarmFix =>
      widget.isActive &&
      _appVisible &&
      !_progress.active &&
      _progress.visitedCount == 0 &&
      widget.services.trail is DeviceTrailService;

  void _syncWarmFix() {
    if (_wantsWarmFix) {
      _warmFix ??= widget.services.location.positions.listen(
        (fix) {
          if (mounted) setState(() => _fix = fix);
        },
        // A missing fix only falls back to the official first stop.
        onError: (Object _) {},
      );
    } else if (_warmFix != null) {
      _warmFix?.cancel();
      _warmFix = null;
      _fix = null;
    }
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
    for (final poi in _pois) {
      if (poi.id == id && _progress.order.contains(id)) return poi;
    }
    return null;
  }

  Poi? get _nextPoi => _poiById(_progress.nextPoiId);

  /// The stop "Mulai Trail" will actually lead to. Before the first start
  /// the device trail still picks the nearest stop, so the preview asks it
  /// with the same rule instead of showing trailOrder 1 and then jumping.
  Poi? get _effectiveFirstStop {
    if (widget.services.trail case final DeviceTrailService device
        when !_progress.active && _progress.visitedCount == 0) {
      final preview = _poiById(device.previewFirstStopId(_fix?.position));
      if (preview != null) return preview;
    }
    return _nextPoi;
  }

  bool _hasArrivedAt(Poi poi) =>
      _navigation.target?.id == poi.id &&
      _navigation.status == NavigationStatus.arrived;

  bool _canContinue(Poi? destination) {
    if (_busy) return false;
    if (destination == null && _effectiveFirstStop == null) {
      _message('Semua gedung pada trail sudah dikunjungi.');
      return false;
    }
    return true;
  }

  /// A Trail session needs precise location while in use (PRD §6); the
  /// request runs only before the session starts.
  Future<bool> _ensureLocationPermission() async {
    if (widget.services.session.current.mode == SessionMode.trail) return true;
    final status = await widget.services.permissions.requestLocation();
    if (status == LocationPermissionStatus.granted) return true;
    if (mounted) {
      _message(
        status == LocationPermissionStatus.serviceDisabled
            ? 'Aktifkan GPS perangkat untuk memulai Orientation Trail.'
            : 'Izin lokasi akurat saat aplikasi digunakan diperlukan.',
      );
    }
    return false;
  }

  /// Starts the trail session and its navigation; throws [StateError] when
  /// the trail cannot start. Each step runs only when it is still needed, so
  /// resuming a running trail never restarts its route.
  Future<void> _startTrail(Poi? destination) async {
    final services = widget.services;
    await services.trail.start();
    // The first start picks the nearest POI and rotates the order, so the
    // next stop is read only after start().
    final targetPoi =
        destination ??
        _poiById(services.trail.current.nextPoiId) ??
        _poiFromAll(services.trail.current.nextPoiId);
    if (targetPoi == null) throw StateError('Trail belum dapat dimulai.');
    if (services.session.current.mode != SessionMode.trail) {
      await services.session.start(SessionMode.trail);
    }
    final navigation = services.navigation.current;
    if (navigation.target?.id != targetPoi.id ||
        navigation.status == NavigationStatus.idle ||
        navigation.status == NavigationStatus.error) {
      await services.navigation.start(NavigationTarget.poi(targetPoi));
    }
  }

  Poi? _poiFromAll(String? id) {
    for (final poi in _pois) {
      if (poi.id == id) return poi;
    }
    return null;
  }

  /// Rute on a stop and the bottom action both open UI06. A preview there
  /// starts the trail on "Mulai rute"; a route already running opens on its
  /// walk. "Akhiri rute" there stops only this leg: the trail keeps running
  /// until "Akhiri Trail" here.
  Future<void> _routeTrail([Poi? destination]) async {
    if (!_canContinue(destination)) return;
    final poi = destination ?? _effectiveFirstStop;
    if (poi == null) return;
    setState(() => _busy = true);
    final bool allowed;
    try {
      allowed = await _ensureLocationPermission();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!allowed || !mounted) return;
    final navigation = widget.services.navigation;
    await WalkingNavigationScreen.open(
      context,
      services: widget.services,
      target: NavigationTarget.poi(poi),
      trail: true,
      start: () => _startTrail(destination),
      end: navigation.stop,
    );
  }

  Future<void> _endTrail() async {
    await widget.services.navigation.stop();
    await widget.services.session.end();
    await widget.services.trail.stop();
  }

  Future<void> _openPoiDetails(Poi poi) async {
    // The detail pops itself after Rute; the preview opens once it is gone.
    var routeRequested = false;
    await Navigator.of(context).push<void>(
      AgamMotion.route(
        (_) => PoiDetailScreen(
          poi: poi,
          activity: widget.services.activity,
          audio: widget.services.audio,
          settings: widget.services.settings,
          checkedIn: _progress.visited.contains(poi.id),
          navigationAvailable: true,
          onNavigate: () async {
            routeRequested = true;
          },
        ),
      ),
    );
    if (mounted && routeRequested) await _routeTrail(poi);
  }

  void _showCheckInStatus(Poi poi, {required bool checkedIn}) {
    _message(
      checkedIn
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
    final nextPoi = _effectiveFirstStop;
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
                                // An empty order means the official trail
                                // is not set yet, not an empty filter.
                                _progress.order.isEmpty
                                    ? 'Urutan Orientation Trail belum tersedia.'
                                    : _filter == 2
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
                              isNext: visible[i].id == nextPoi?.id,
                              isActive: _progress.active,
                              expanded: _detailPoiId == visible[i].id,
                              navigationState: _navigation,
                              onExpand: () => setState(
                                () =>
                                    _detailPoiId = _detailPoiId == visible[i].id
                                    ? null
                                    : visible[i].id,
                              ),
                              // Only the next stop has this button; it is
                              // the stop the trail will start toward.
                              onRoute: () => _routeTrail(),
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
            nextPoi: nextPoi,
            busy: _busy,
            isActive: _progress.active,
            hasProgress: completed > 0,
            navigation: _navigation,
            onContinue: _routeTrail,
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
                    ? 'Trail selesai. Lencana terbuka.'
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
                            AgamAnimatedSize(
                              milliseconds: 240,
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
                          if (done) ...[
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
                          ] else if (isActive && isArrived) ...[
                            // A Trail arrival checks in on its own; until the
                            // record lands, nothing pretends it is done.
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.where_to_vote_rounded,
                                  size: 18,
                                  color: AgamColors.success,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Anda sudah tiba. Check-in sedang dicatat.',
                                    style: AgamText.caption,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 104,
                                  child: AgamTonalButton(
                                    onPressed: onDetails,
                                    height: 44,
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
                                  flex: 2,
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
                                // AgamTonalButton has no intrinsic width
                                // (its minimum width is infinite), so it
                                // needs a flex share inside a Row.
                                Expanded(
                                  child: AgamTonalButton(
                                    onPressed: onDetails,
                                    height: 44,
                                    label: 'Detail',
                                  ),
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
    required this.busy,
    required this.isActive,
    required this.hasProgress,
    required this.navigation,
    required this.onContinue,
    required this.onEnd,
  });

  final Poi? nextPoi;
  final bool busy;
  final bool isActive;
  final bool hasProgress;
  final NavigationState navigation;
  final Future<void> Function([Poi?]) onContinue;
  final Future<void> Function() onEnd;

  static const _walkingStatuses = {
    NavigationStatus.calculating,
    NavigationStatus.onRoute,
    NavigationStatus.offRoute,
    NavigationStatus.rerouting,
  };

  @override
  Widget build(BuildContext context) {
    final poi = nextPoi;
    final towardNext =
        poi != null &&
        navigation.target?.id == poi.id &&
        _walkingStatuses.contains(navigation.status);
    // The label stays a short verb; the stop and distance get their own
    // line above, so a long building name never truncates the action.
    final buttonText = isActive
        ? (towardNext ? 'Lanjutkan navigasi' : 'Buka peta rute')
        : hasProgress
        ? 'Lanjutkan Trail'
        : 'Mulai Trail';
    final remaining = towardNext ? navigation.remainingDistanceM : null;
    final approximateDestination =
        isActive &&
        navigation.target?.isPlaceholderPoint == true &&
        navigation.status != NavigationStatus.arrived &&
        navigation.status != NavigationStatus.error;
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
            if (poi != null) ...[
              _NextStopLine(
                name: poi.name,
                remainingM: remaining,
                approximate: approximateDestination,
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: AgamPrimaryButton(
                    onPressed: busy || poi == null ? null : () => onContinue(),
                    busy: busy,
                    icon: isActive
                        ? Icons.navigation_rounded
                        : Icons.flag_rounded,
                    label: buttonText,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'Akhiri Trail',
                    child: Semantics(
                      button: true,
                      label: 'Akhiri Trail',
                      excludeSemantics: true,
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

/// "Tujuan berikutnya" with the stop name on up to two lines and the live
/// remaining distance in tabular figures, so the number never jitters.
class _NextStopLine extends StatelessWidget {
  const _NextStopLine({
    required this.name,
    required this.remainingM,
    required this.approximate,
  });

  final String name;
  final double? remainingM;
  final bool approximate;

  @override
  Widget build(BuildContext context) {
    final distance = remainingM == null ? null : '${remainingM!.round()} m';
    return Semantics(
      container: true,
      label: [
        'Tujuan berikutnya: $name',
        ?distance,
        if (approximate) 'Tujuan perkiraan',
      ].join(', '),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AgamColors.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.place_rounded,
              size: 20,
              color: AgamColors.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  approximate ? 'Tujuan perkiraan' : 'Tujuan berikutnya',
                  style: AgamText.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AgamText.label,
                ),
              ],
            ),
          ),
          if (distance != null) ...[
            const SizedBox(width: 12),
            // Updates with every fix, so it changes in place without motion.
            Text(
              distance,
              style: AgamText.label.copyWith(
                color: AgamColors.brand,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
