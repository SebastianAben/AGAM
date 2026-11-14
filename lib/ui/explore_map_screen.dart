import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../contracts/app_services.dart';
import '../contracts/models/content.dart';
import '../contracts/models/geo.dart';
import '../contracts/models/location.dart';
import '../contracts/models/session.dart';
import 'orientation_trail_screen.dart';
import 'widgets/agam_bottom_navigation.dart';

/// UI02 Explore Map. UI03 trigger and UI04 detail are states layered over it.
class ExploreMapScreen extends StatefulWidget {
  const ExploreMapScreen({
    super.key,
    required this.services,
    this.embedded = false,
    this.isActive = true,
    this.onTabSelected,
  });

  final AppServices services;
  final bool embedded;
  final bool isActive;
  final ValueChanged<int>? onTabSelected;

  @override
  State<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends State<ExploreMapScreen> {
  static const _navy = Color(0xFF073B82);
  static const _blue = Color(0xFF1553A6);

  final _subscriptions = <StreamSubscription<dynamic>>[];
  StreamSubscription<LocationFix>? _locationSubscription;
  List<Poi> _pois = const [];
  List<Facility> _nearbyFacilities = const [];
  LocationFix? _fix;
  Poi? _selectedPoi;
  bool _sessionActive = false;
  bool _showDetail = true;
  bool _expandedDetail = false;
  bool _isUiPreview = true;

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      widget.services.pois.watchPois().listen((pois) {
        if (!mounted) return;
        setState(() {
          _pois = pois;
          _selectedPoi ??= _findPoi('P07');
        });
        _loadFacilities();
      }),
    );
    _syncLocationSubscription();
    _subscriptions.add(
      widget.services.session.state.listen((state) {
        if (!mounted) return;
        setState(() => _sessionActive = state.isActive);
      }),
    );
    _subscriptions.add(
      widget.services.session.triggers.listen((event) {
        if (!mounted) return;
        final poi = _findPoi(event.poiId);
        if (poi == null) return;
        setState(() {
          _selectedPoi = poi;
          _showDetail = true;
          _expandedDetail = false;
          _isUiPreview = false;
        });
        _loadFacilities();
      }),
    );
  }

  @override
  void didUpdateWidget(covariant ExploreMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncLocationSubscription();
    }
  }

  void _syncLocationSubscription() {
    if (widget.isActive) {
      _locationSubscription ??= widget.services.location.positions.listen((
        fix,
      ) {
        if (!mounted) return;
        setState(() => _fix = fix);
      });
    } else {
      final subscription = _locationSubscription;
      _locationSubscription = null;
      unawaited(subscription?.cancel());
    }
  }

  Poi? _findPoi(String id) {
    for (final poi in _pois) {
      if (poi.id == id) return poi;
    }
    return null;
  }

  Future<void> _loadFacilities() async {
    final poi = _selectedPoi;
    if (poi == null) return;
    final facilities = await widget.services.facilities.nearby(
      from: poi.position,
      limit: 4,
    );
    if (mounted) {
      setState(
        () => _nearbyFacilities = facilities
            .map((item) => item.facility)
            .toList(),
      );
    }
  }

  Future<void> _toggleSession() async {
    if (_sessionActive) {
      await widget.services.session.end();
    } else {
      setState(() => _isUiPreview = false);
      await widget.services.session.start(SessionMode.explore);
    }
  }

  void _selectPoi(Poi poi) {
    setState(() {
      _selectedPoi = poi;
      _showDetail = true;
      _expandedDetail = false;
      _isUiPreview = false;
    });
    _loadFacilities();
  }

  @override
  void dispose() {
    unawaited(_locationSubscription?.cancel());
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poi = _selectedPoi;
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAFF),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (!widget.embedded)
              _TopBar(onProfile: () => _showNotice('Profil belum tersedia')),
            _LocationStatus(fix: _fix, pois: _pois),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  fit: StackFit.expand,
                  children: [
                    _MapCanvas(
                      pois: _pois,
                      selectedPoi: poi,
                      userPosition: _fix?.position,
                      onSelectPoi: _selectPoi,
                      preview: _isUiPreview,
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _MapControls(
                        sessionActive: _sessionActive,
                        onSession: _toggleSession,
                        onNotice: _showNotice,
                      ),
                    ),
                    if (poi != null && _showDetail)
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 0,
                        height: math.min(452, constraints.maxHeight * 0.65),
                        child: _PoiSheet(
                          poi: poi,
                          facilities: _nearbyFacilities,
                          preview: _isUiPreview,
                          expanded: _expandedDetail,
                          onToggleExpanded: () => setState(
                            () => _expandedDetail = !_expandedDetail,
                          ),
                          onClose: () => setState(() => _showDetail = false),
                          onSkip: () => setState(() {
                            _showDetail = false;
                            _isUiPreview = false;
                          }),
                          onNotice: _showNotice,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!widget.embedded)
              SafeArea(
                top: false,
                child: AgamBottomNavigation(
                  selectedIndex: 0,
                  onSelect: _openTab,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _openTab(int index) {
    if (widget.onTabSelected != null) {
      widget.onTabSelected!(index);
      return;
    }
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OrientationTrailScreen(services: widget.services),
        ),
      );
    } else if (index == 2) {
      _showNotice('Pencarian dan rute akan tersedia pada UI05–UI06');
    } else if (index == 3) {
      _showNotice('Pengaturan akan tersedia pada UI09');
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onProfile});

  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white,
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
          InkWell(
            onTap: onProfile,
            customBorder: const CircleBorder(),
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFE7E9F2),
              child: Icon(
                Icons.person_rounded,
                color: Color(0xFF50576A),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationStatus extends StatelessWidget {
  const _LocationStatus({required this.fix, required this.pois});

  final LocationFix? fix;
  final List<Poi> pois;

  @override
  Widget build(BuildContext context) {
    final nearest = fix == null || pois.isEmpty
        ? null
        : pois.reduce(
            (a, b) =>
                fix!.position.distanceTo(a.position) <
                    fix!.position.distanceTo(b.position)
                ? a
                : b,
          );
    return Container(
      height: 40,
      alignment: Alignment.center,
      color: Colors.white,
      child: Container(
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFF),
          border: Border.all(color: const Color(0xFFEDEEF5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 9, color: Color(0xFF006B51)),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                nearest == null
                    ? 'Mencari posisi Anda'
                    : 'Dekat ${nearest.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E9FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                fix == null
                    ? 'GPS mencari…'
                    : 'GPS ±${fix!.accuracyM.round()}m',
                style: const TextStyle(
                  color: Color(0xFF164FA1),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 7),
            const Icon(Icons.circle, size: 6, color: Color(0xFF006B51)),
          ],
        ),
      ),
    );
  }
}

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.pois,
    required this.selectedPoi,
    required this.userPosition,
    required this.onSelectPoi,
    required this.preview,
  });

  final List<Poi> pois;
  final Poi? selectedPoi;
  final GeoPoint? userPosition;
  final ValueChanged<Poi> onSelectPoi;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final points = pois.isEmpty
            ? const <GeoPoint>[]
            : pois.map((poi) => poi.position).toList();
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _SchematicMapPainter(
                pois: pois,
                userPosition: userPosition,
              ),
            ),
            Positioned(
              left: 12,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  preview ? 'PRATINJAU UI • PETA ILUSTRASI' : 'PETA ILUSTRASI',
                  style: const TextStyle(
                    color: Color(0xFF68708A),
                    fontSize: 8,
                    letterSpacing: 0.55,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            for (final poi in pois)
              if (poi != selectedPoi)
                _poiMarker(poi, _project(poi.position, points, size)),
            if (selectedPoi != null)
              _selectedMarker(
                selectedPoi!,
                _project(selectedPoi!.position, points, size),
              ),
            if (userPosition != null)
              _userMarker(_project(userPosition!, points, size)),
          ],
        );
      },
    );
  }

  Widget _poiMarker(Poi poi, Offset point) => Positioned(
    left: (point.dx - 33).clamp(2, double.infinity),
    top: (point.dy - 15).clamp(44, double.infinity),
    child: GestureDetector(
      onTap: () => onSelectPoi(poi),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 5)],
        ),
        child: Text(
          poi.name,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );

  Widget _selectedMarker(Poi poi, Offset point) => Positioned(
    left: (point.dx - 56).clamp(4, double.infinity),
    top: (point.dy - 34).clamp(50, double.infinity),
    child: GestureDetector(
      onTap: () => onSelectPoi(poi),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF073B82),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 3),
            Text(
              poi.aliases.isEmpty ? poi.name : poi.aliases.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _userMarker(Offset point) => Positioned(
    left: point.dx - 15,
    top: point.dy - 15,
    child: Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0x3329B6F6),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x6642BDF5), width: 2),
      ),
      child: Center(
        child: Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: const Color(0xFF073B82),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    ),
  );

  Offset _project(GeoPoint point, List<GeoPoint> all, Size size) {
    if (all.isEmpty) return Offset(size.width / 2, size.height / 2);
    final minLat = all.map((item) => item.lat).reduce(math.min);
    final maxLat = all.map((item) => item.lat).reduce(math.max);
    final minLng = all.map((item) => item.lng).reduce(math.min);
    final maxLng = all.map((item) => item.lng).reduce(math.max);
    final lngRange = math.max(maxLng - minLng, 0.00001);
    final latRange = math.max(maxLat - minLat, 0.00001);
    final x = 22 + ((point.lng - minLng) / lngRange) * (size.width - 60);
    final y = 65 + ((maxLat - point.lat) / latRange) * (size.height * 0.48);
    return Offset(x, y);
  }
}

class _SchematicMapPainter extends CustomPainter {
  const _SchematicMapPainter({required this.pois, required this.userPosition});

  final List<Poi> pois;
  final GeoPoint? userPosition;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFF1F3FF), BlendMode.src);
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roadEdge = Paint()
      ..color = const Color(0xFFD7E0FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Decorative road geometry is explicitly marked as an illustration.
    final paths = [
      Path()
        ..moveTo(size.width * 0.49, 0)
        ..lineTo(size.width * 0.49, size.height),
      Path()
        ..moveTo(size.width * 0.08, size.height * 0.40)
        ..lineTo(size.width * 0.92, size.height * 0.40),
      Path()
        ..moveTo(size.width * 0.13, size.height * 0.70)
        ..lineTo(size.width * 0.90, size.height * 0.70),
      Path()
        ..moveTo(size.width * 0.24, size.height * 0.27)
        ..lineTo(size.width * 0.82, size.height * 0.64),
      Path()
        ..moveTo(size.width * 0.78, size.height * 0.25)
        ..lineTo(size.width * 0.23, size.height * 0.70),
    ];
    for (final path in paths) {
      canvas.drawPath(path, road);
      canvas.drawPath(path, roadEdge);
    }

    final parkPaint = Paint()..color = const Color(0xFFD9F3EF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.18,
          size.height * 0.14,
          size.width * 0.64,
          30,
        ),
        const Radius.circular(10),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.34,
          size.height * 0.52,
          size.width * 0.16,
          44,
        ),
        const Radius.circular(22),
      ),
      parkPaint,
    );

    final label = TextPainter(
      text: const TextSpan(
        text: 'PETA SKEMATIS',
        style: TextStyle(
          color: Color(0x99717A96),
          fontSize: 8,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(size.width - label.width - 14, size.height - 18),
    );
  }

  @override
  bool shouldRepaint(covariant _SchematicMapPainter oldDelegate) =>
      oldDelegate.pois != pois || oldDelegate.userPosition != userPosition;
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.sessionActive,
    required this.onSession,
    required this.onNotice,
  });

  final bool sessionActive;
  final VoidCallback onSession;
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ControlButton(
          icon: Icons.explore_outlined,
          onTap: () => onNotice('Kompas peta'),
        ),
        const SizedBox(height: 7),
        _ControlButton(
          icon: Icons.my_location_rounded,
          onTap: () => onNotice('Posisi diperbarui'),
        ),
        const SizedBox(height: 7),
        _ControlButton(
          icon: Icons.layers_outlined,
          onTap: () => onNotice('Pilihan lapisan peta'),
        ),
        const SizedBox(height: 7),
        Material(
          color: sessionActive
              ? const Color(0xFFB33D55)
              : const Color(0xFF007C83),
          shape: const CircleBorder(),
          elevation: 3,
          child: InkWell(
            onTap: onSession,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                sessionActive
                    ? Icons.stop_rounded
                    : Icons.people_outline_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    elevation: 2,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 39,
        height: 39,
        child: Icon(icon, color: const Color(0xFF174F9E), size: 20),
      ),
    ),
  );
}

class _PoiSheet extends StatelessWidget {
  const _PoiSheet({
    required this.poi,
    required this.facilities,
    required this.preview,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onClose,
    required this.onSkip,
    required this.onNotice,
  });

  final Poi poi;
  final List<Facility> facilities;
  final bool preview;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onClose;
  final VoidCallback onSkip;
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    final prompt =
        '“Anda mendekati ${poi.name}. Apakah Anda ingin mendengarkan ceritanya?”';
    return Material(
      color: Colors.white,
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
      child: Column(
        children: [
          const SizedBox(height: 9),
          Container(
            width: 34,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFC4C9D9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 12, 7),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4BD8F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                    color: Color(0xFF00536B),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    poi.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: expanded ? onToggleExpanded : onClose,
                  tooltip: expanded ? 'Ciutkan informasi' : 'Tutup informasi',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE9ECFF),
                    foregroundColor: const Color(0xFF35415E),
                    fixedSize: const Size(34, 34),
                  ),
                  icon: Icon(
                    expanded ? Icons.expand_more : Icons.close_rounded,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 25,
                          height: 25,
                          decoration: const BoxDecoration(
                            color: _ExploreMapScreenState._blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.campaign_outlined,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preview
                                    ? 'Pratinjau prompt suara'
                                    : 'Pemandu AGAM Suara',
                                style: const TextStyle(
                                  color: _ExploreMapScreenState._navy,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                prompt,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.25,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: facilities.isEmpty
                        ? [
                            const _FacilityChip(
                              label: 'Fasilitas belum tersedia',
                            ),
                          ]
                        : facilities
                              .map(
                                (facility) => _FacilityChip(
                                  label: facility.name.contains('(contoh)')
                                      ? facility.name
                                      : '${facility.name} · contoh',
                                ),
                              )
                              .toList(),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 94,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EDF4),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            size: 26,
                            color: Color(0xFF8792A4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            poi.media.photos.isEmpty
                                ? 'Foto belum tersedia · placeholder'
                                : 'Foto POI',
                            style: const TextStyle(
                              color: Color(0xFF596477),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8FC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        poi.metadata.isPlaceholder
                            ? 'PLACEHOLDER — menunggu tim konten'
                            : poi.description,
                        style: const TextStyle(fontSize: 11, height: 1.35),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: poi.media.narrationAudio == null
                          ? null
                          : () => onNotice(
                              'Pemutar narasi akan dihubungkan pada PB08',
                            ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF063B82),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF063B82),
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      icon: const Icon(Icons.headphones_rounded, size: 22),
                      label: Text(
                        poi.media.narrationAudio == null
                            ? 'Narasi belum tersedia'
                            : 'Dengarkan Cerita',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              onNotice('Konten detail masih placeholder'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFE7EAFF),
                            foregroundColor: _ExploreMapScreenState._navy,
                            side: BorderSide.none,
                            minimumSize: const Size.fromHeight(40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.info_outline, size: 17),
                          label: const Text(
                            'Info Lengkap',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onSkip,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFE7EAFF),
                            foregroundColor: const Color(0xFF454B5B),
                            side: BorderSide.none,
                            minimumSize: const Size.fromHeight(40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.timer_outlined, size: 17),
                          label: const Text(
                            'Lewati',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  const Center(
                    child: Text(
                      'Ketuk dua kali di layar untuk perintah suara instan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF747B8B),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FacilityChip extends StatelessWidget {
  const _FacilityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE9ECFF),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
    ),
  );
}
