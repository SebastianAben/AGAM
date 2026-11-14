import 'dart:async';

import 'package:flutter/material.dart';

import '../contracts/app_services.dart';
import '../contracts/models/content.dart';
import '../contracts/models/discovery.dart';
import '../contracts/models/navigation.dart';
import '../contracts/models/session.dart';
import 'poi_detail_screen.dart';
import 'widgets/agam_bottom_navigation.dart';

/// UI08 Orientation Trail. The inline map preview is a UI02 component, and
/// the route action starts UI06. UI07 recommendation results remain separate.
class OrientationTrailScreen extends StatefulWidget {
  const OrientationTrailScreen({
    super.key,
    required this.services,
    this.embedded = false,
    this.onTabSelected,
  });

  final AppServices services;
  final bool embedded;
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
    _progress = widget.services.trail.current;
    _subscriptions.add(
      widget.services.pois.watchPois().listen((pois) {
        if (mounted) setState(() => _pois = pois);
      }),
    );
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
    await widget.services.navigation.stop();
    await widget.services.session.end();
    await widget.services.trail.stop();
  }

  Future<void> _openPoiDetails(Poi poi) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PoiDetailScreen(
          poi: poi,
          audio: widget.services.audio,
          checkedIn: _progress.visited.contains(poi.id),
          onNavigate: () => _continueTrail(poi),
        ),
      ),
    );
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
    final nextPoi = _nextPoi;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FF),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (!widget.embedded) const _TrailTopBar(),
            Expanded(
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                clipBehavior: Clip.hardEdge,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    sliver: SliverList.list(
                      children: [
                        _TrailOverview(
                          progress: _progress,
                          percent: percent,
                          isExample: true,
                        ),
                        const SizedBox(height: 12),
                        _AchievementCard(progress: _progress, percent: percent),
                        const SizedBox(height: 12),
                        const _TrailNotice(),
                        const SizedBox(height: 14),
                        _TrailFilters(
                          filter: _filter,
                          all: _orderedPois.length,
                          pending: _orderedPois.length - completed,
                          completed: completed,
                          onChanged: (filter) =>
                              setState(() => _filter = filter),
                        ),
                        const SizedBox(height: 12),
                        for (final entry in _visiblePois) ...[
                          _TrailPoiCard(
                            index: _progress.order.indexOf(entry.id) + 1,
                            poi: entry,
                            done: _progress.visited.contains(entry.id),
                            isArrived: _hasArrivedAt(entry),
                            isNext: entry.id == _progress.nextPoiId,
                            isActive: widget.services.trail.current.active,
                            expanded: _detailPoiId == entry.id,
                            navigationState: _navigation,
                            onExpand: () => setState(
                              () => _detailPoiId = _detailPoiId == entry.id
                                  ? null
                                  : entry.id,
                            ),
                            onRoute: () => _continueTrail(entry),
                            onCheckIn: () => _showCheckInStatus(
                              entry,
                              checkedIn: _progress.visited.contains(entry.id),
                            ),
                            onDetails: () => _openPoiDetails(entry),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 10),
                        const _TrailMapPreview(),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _TrailBottomArea(
              nextPoi: nextPoi,
              busy: _busy,
              isActive: _progress.active,
              navigation: _navigation,
              onContinue: _continueTrail,
              onEnd: _endTrail,
              embedded: widget.embedded,
              onTab: (index) {
                if (widget.onTabSelected != null) {
                  widget.onTabSelected!(index);
                  return;
                }
                if (index == 0) {
                  Navigator.of(context).pop();
                }
                if (index == 2) {
                  _message('Pencarian dan rute tersedia di UI05–UI06.');
                }
                if (index == 3) {
                  _message('Pengaturan tersedia di UI09.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailTopBar extends StatelessWidget {
  const _TrailTopBar();

  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF104DA5),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(
            Icons.explore_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const Spacer(),
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xFFE7E9F2),
          child: Icon(Icons.person_rounded, color: Color(0xFF50576A), size: 20),
        ),
      ],
    ),
  );
}

class _TrailOverview extends StatelessWidget {
  const _TrailOverview({
    required this.progress,
    required this.percent,
    required this.isExample,
  });

  final TrailProgress progress;
  final double percent;
  final bool isExample;

  @override
  Widget build(BuildContext context) {
    final count = progress.visitedCount;
    final total = progress.total;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100C2452),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E9FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        size: 13,
                        color: _TrailColors.navy,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Orientation Trail Ganesha',
                      style: TextStyle(
                        color: _TrailColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              _ProgressRing(progress: percent, count: count, total: total),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Panduan untuk mengenal 10 gedung dan fasilitas di Kampus ITB Ganesha.',
            style: TextStyle(
              color: Color(0xFF606675),
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
          if (isExample) ...[
            const SizedBox(height: 6),
            const Text(
              'Urutan pada layar ini masih contoh sintetis; urutan resmi belum ditetapkan.',
              style: TextStyle(
                color: Color(0xFF71798A),
                fontSize: 9.5,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.check_circle_outline,
                  label: 'Selesai',
                  value: '$count / $total POI',
                  color: const Color(0xFF006652),
                ),
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: _SummaryTile(
                  icon: Icons.route_outlined,
                  label: 'Jarak',
                  value: 'Belum dihitung',
                  color: Color(0xFF007782),
                ),
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: _SummaryTile(
                  icon: Icons.timer_outlined,
                  label: 'Estimasi',
                  value: 'Belum tersedia',
                  color: Color(0xFF164D9A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
  Widget build(BuildContext context) => SizedBox(
    width: 53,
    height: 53,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CircularProgressIndicator(
          value: progress,
          strokeWidth: 4,
          backgroundColor: const Color(0xFFE0E5F7),
          color: const Color(0xFF174FA5),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _TrailColors.navy,
              ),
            ),
            Text(
              '$count/$total',
              style: const TextStyle(fontSize: 8, color: Color(0xFF73798B)),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 53,
    padding: const EdgeInsets.fromLTRB(7, 6, 4, 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F2FF),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF5E6575),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: _TrailColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.progress, required this.percent});

  final TrailProgress progress;
  final double percent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0D4A99), Color(0xFF173A73)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(13),
      boxShadow: const [
        BoxShadow(
          color: Color(0x220C2452),
          blurRadius: 7,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.emoji_events_outlined,
            color: Color(0xFF55D6ED),
            size: 26,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lencana Penjelajah Ganesha',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                progress.isComplete
                    ? 'Trail selesai — lencana terbuka.'
                    : 'Selesaikan 10/10 POI untuk membuka lencana.',
                style: const TextStyle(
                  color: Color(0xFFD5E3FF),
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 5,
                  backgroundColor: const Color(0xFF52647F),
                  color: const Color(0xFF4BD5EF),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TrailNotice extends StatelessWidget {
  const _TrailNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFE7EBFF),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Row(
      children: [
        Icon(
          Icons.lightbulb_outline_rounded,
          size: 20,
          color: Color(0xFF00788A),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Urutan trail resmi belum tersedia',
                style: TextStyle(
                  fontSize: 11,
                  color: _TrailColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Daftar di bawah memakai urutan contoh sintetis.',
                style: TextStyle(fontSize: 9.5, color: Color(0xFF636B7A)),
              ),
            ],
          ),
        ),
        Icon(Icons.info_outline, size: 17, color: Color(0xFF1553A6)),
      ],
    ),
  );
}

class _TrailFilters extends StatelessWidget {
  const _TrailFilters({
    required this.filter,
    required this.all,
    required this.pending,
    required this.completed,
    required this.onChanged,
  });

  final int filter;
  final int all;
  final int pending;
  final int completed;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = [
      'Semua Rute ($all)',
      'Belum Dikunjungi ($pending)',
      'Selesai ($completed)',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            ChoiceChip(
              label: Text(labels[index]),
              selected: filter == index,
              onSelected: (_) => onChanged(index),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 10,
                color: filter == index ? Colors.white : const Color(0xFF424A5C),
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: const Color(0xFFE6E9FA),
              selectedColor: const Color(0xFF0C478F),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 5),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrailPoiCard extends StatelessWidget {
  const _TrailPoiCard({
    required this.index,
    required this.poi,
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
  final bool done;
  final bool isArrived;
  final bool isNext;
  final bool isActive;
  final bool expanded;
  final NavigationState navigationState;
  final VoidCallback onExpand;
  final VoidCallback onRoute;
  final VoidCallback onCheckIn;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final routing =
        navigationState.target?.id == poi.id &&
        navigationState.status != NavigationStatus.idle;
    final cardColor = isNext ? const Color(0xFFE8EBFF) : Colors.white;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 29,
          child: Padding(
            padding: const EdgeInsets.only(top: 11),
            child: _TrailStepMarker(index: index, done: done, isNext: isNext),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Material(
            color: cardColor,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              onTap: onExpand,
              borderRadius: BorderRadius.circular(13),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isNext
                        ? const Color(0xFF80BCC8)
                        : const Color(0xFFF0EFF5),
                    width: isNext ? 1.3 : 0.7,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            poi.name,
                            style: const TextStyle(
                              color: _TrailColors.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        _StatusPill(
                          label: done
                              ? 'Selesai'
                              : isNext
                              ? 'Berikutnya'
                              : 'Belum dikunjungi',
                          done: done,
                          highlighted: isNext,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _categoryIcon(poi.category),
                          size: 13,
                          color: const Color(0xFF596477),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            poi.metadata.isPlaceholder || !poi.metadata.approved
                                ? 'Deskripsi menunggu tim konten.'
                                : poi.description,
                            maxLines: expanded ? null : 2,
                            overflow: expanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF626978),
                              fontSize: 10.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (expanded) ...[
                      const SizedBox(height: 7),
                      Text(
                        'ID POI: ${poi.id} · Radius trigger: ${poi.radiusM.round()} m',
                        style: const TextStyle(
                          color: Color(0xFF767D8C),
                          fontSize: 9,
                        ),
                      ),
                      if (!poi.hasSurveyedEntrance)
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Text(
                            'Pintu masuk belum disurvei; titik tengah gedung hanya placeholder.',
                            style: TextStyle(
                              color: Color(0xFF767D8C),
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                    if (done || isArrived) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onCheckIn,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(34),
                                backgroundColor: const Color(0xFF087B86),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 15,
                              ),
                              label: const Text(
                                'Check-in',
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          TextButton.icon(
                            onPressed: onDetails,
                            icon: const Icon(Icons.info_outline, size: 14),
                            label: const Text(
                              'Details',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ] else if (isNext) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: onRoute,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                backgroundColor: const Color(0xFF087B86),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(
                                routing
                                    ? Icons.navigation_rounded
                                    : Icons.check_circle_outline,
                                size: 14,
                              ),
                              label: Text(
                                routing
                                    ? 'Sedang menuju'
                                    : isActive
                                    ? 'Lanjutkan rute'
                                    : 'Pilih rute',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: onExpand,
                            child: const Text(
                              'Detail',
                              style: TextStyle(fontSize: 10),
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
      ],
    );
  }

  IconData _categoryIcon(PoiCategory category) =>
      category == PoiCategory.lecture
      ? Icons.account_balance_outlined
      : Icons.science_outlined;
}

class _TrailStepMarker extends StatelessWidget {
  const _TrailStepMarker({
    required this.index,
    required this.done,
    required this.isNext,
  });

  final int index;
  final bool done;
  final bool isNext;

  @override
  Widget build(BuildContext context) => Container(
    width: 25,
    height: 25,
    decoration: BoxDecoration(
      color: done
          ? const Color(0xFF00523D)
          : isNext
          ? const Color(0xFF36C8DE)
          : const Color(0xFFE0E5FF),
      shape: BoxShape.circle,
      border: Border.all(
        color: isNext ? const Color(0xFFB9F4FC) : Colors.transparent,
        width: 3,
      ),
    ),
    child: Icon(
      done
          ? Icons.check
          : isNext
          ? Icons.my_location_rounded
          : null,
      size: 13,
      color: done ? Colors.white : const Color(0xFF164C8F),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.done,
    required this.highlighted,
  });

  final String label;
  final bool done;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: done
          ? const Color(0xFFE7F1EC)
          : highlighted
          ? const Color(0xFFDCE5FF)
          : const Color(0xFFE9EAF0),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 8.5,
        color: done
            ? const Color(0xFF28664E)
            : highlighted
            ? const Color(0xFF20467E)
            : const Color(0xFF606778),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _TrailMapPreview extends StatelessWidget {
  const _TrailMapPreview();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: const Color(0xFFE8EBFF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.map_outlined, size: 15, color: _TrailColors.navy),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                'Peta Orientasi Kampus',
                style: TextStyle(
                  color: _TrailColors.ink,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 142,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(9)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _MiniSchematicPainter()),
              Positioned(
                left: 7,
                top: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PETA ILUSTRASI · DATA PETA MENUNGGU LB',
                    style: TextStyle(
                      color: Color(0xFF56627A),
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'Peta belum tersedia',
                  style: TextStyle(
                    color: Color(0xFF596477),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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

class _MiniSchematicPainter extends CustomPainter {
  const _MiniSchematicPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFEAF5EF), BlendMode.src);
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 11
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final edge = Paint()
      ..color = const Color(0xFFC8D8FA)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final paths = [
      Path()
        ..moveTo(-5, size.height * .25)
        ..lineTo(size.width + 5, size.height * .25),
      Path()
        ..moveTo(-5, size.height * .65)
        ..lineTo(size.width + 5, size.height * .65),
      Path()
        ..moveTo(size.width * .25, -5)
        ..lineTo(size.width * .25, size.height + 5),
      Path()
        ..moveTo(size.width * .72, -5)
        ..lineTo(size.width * .72, size.height + 5),
      Path()
        ..moveTo(size.width * .1, size.height * .9)
        ..lineTo(size.width * .85, size.height * .05),
    ];
    for (final path in paths) {
      canvas.drawPath(path, road);
      canvas.drawPath(path, edge);
    }
    final marker = Paint()..color = const Color(0xFF1B62AA);
    for (final point in [
      Offset(size.width * .18, size.height * .25),
      Offset(size.width * .48, size.height * .42),
      Offset(size.width * .78, size.height * .66),
    ]) {
      canvas.drawCircle(point, 5, marker);
      canvas.drawCircle(point, 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniSchematicPainter oldDelegate) => false;
}

class _TrailBottomArea extends StatelessWidget {
  const _TrailBottomArea({
    required this.nextPoi,
    required this.busy,
    required this.isActive,
    required this.navigation,
    required this.onContinue,
    required this.onEnd,
    required this.onTab,
    required this.embedded,
  });

  final Poi? nextPoi;
  final bool busy;
  final bool isActive;
  final NavigationState navigation;
  final Future<void> Function([Poi?]) onContinue;
  final Future<void> Function() onEnd;
  final ValueChanged<int> onTab;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final buttonText = isActive
        ? 'Lanjutkan Trail: ${nextPoi?.name ?? 'selesai'}'
        : 'Mulai Trail: ${nextPoi?.name ?? 'semua POI selesai'}';
    return Material(
      color: const Color(0xFFFBFAFF),
      elevation: 6,
      child: SafeArea(
        top: false,
        bottom: !embedded,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 43,
                      child: FilledButton.icon(
                        onPressed: busy || nextPoi == null
                            ? null
                            : () => onContinue(),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF073B82),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: busy
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.navigation_outlined, size: 17),
                        label: Row(
                          children: [
                            Expanded(
                              child: Text(
                                buttonText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (navigation.remainingDistanceM != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${navigation.remainingDistanceM!.round()} m →',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      onPressed: onEnd,
                      tooltip: 'Akhiri Trail',
                      icon: const Icon(Icons.stop_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFE6E9FA),
                        foregroundColor: _TrailColors.navy,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!embedded)
              AgamBottomNavigation(selectedIndex: 1, onSelect: onTab),
          ],
        ),
      ),
    );
  }
}

class _TrailColors {
  static const navy = Color(0xFF073B82);
  static const ink = Color(0xFF222A3C);
}
