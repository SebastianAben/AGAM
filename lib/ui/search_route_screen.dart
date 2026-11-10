import 'dart:async';

import 'package:flutter/material.dart';

import '../contracts/app_services.dart';
import '../contracts/models/content.dart';
import '../contracts/models/discovery.dart';
import '../contracts/models/navigation.dart';
import '../contracts/models/session.dart';

/// UI05 Search & Destination plus the active UI06 navigation summary.
/// Search/routing implementations are injected from AppServices; placeholders
/// are identified where the current fake services supply preview data.
class SearchRouteScreen extends StatefulWidget {
  const SearchRouteScreen({
    super.key,
    required this.services,
    this.onTabSelected,
  });

  final AppServices services;
  final ValueChanged<int>? onTabSelected;

  @override
  State<SearchRouteScreen> createState() => _SearchRouteScreenState();
}

class _SearchRouteScreenState extends State<SearchRouteScreen> {
  static const _navy = Color(0xFF073B82);
  static const _blue = Color(0xFF1553A6);
  static const _pale = Color(0xFFE9EDFF);

  final _query = TextEditingController();
  List<Poi> _pois = const [];
  List<Facility> _facilities = const [];
  List<SearchResult> _results = const [];
  SearchResult? _destination;
  NavigationState _navigation = const NavigationState.idle();
  FacilityCategory? _facilityFilter;
  int _poiFilter = 0;
  bool _searching = false;
  bool _routing = false;
  String? _error;
  StreamSubscription<List<Poi>>? _poiSubscription;
  StreamSubscription<List<Facility>>? _facilitySubscription;
  StreamSubscription<NavigationState>? _navigationSubscription;

  @override
  void initState() {
    super.initState();
    _poiSubscription = widget.services.pois.watchPois().listen((value) {
      if (mounted) setState(() => _pois = value);
    });
    _facilitySubscription = widget.services.pois.watchFacilities().listen((
      value,
    ) {
      if (mounted) setState(() => _facilities = value);
    });
    _navigation = widget.services.navigation.current;
    _navigationSubscription = widget.services.navigation.state.listen((value) {
      if (mounted) setState(() => _navigation = value);
    });
    _query.addListener(_runSearch);
  }

  @override
  void dispose() {
    _query
      ..removeListener(_runSearch)
      ..dispose();
    _poiSubscription?.cancel();
    _facilitySubscription?.cancel();
    _navigationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final text = _query.text.trim();
    if (text.isEmpty) {
      if (mounted) setState(() => _results = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await widget.services.search.search(
        text,
        includePois: _facilityFilter == null,
        facilityCategories: _facilityFilter == null ? null : {_facilityFilter!},
      );
      if (mounted) setState(() => _results = result);
    } catch (_) {
      if (mounted) setState(() => _error = 'Pencarian belum dapat dimuat.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _setPoiFilter(int index) {
    setState(() {
      _poiFilter = index;
      _facilityFilter = null;
    });
    _runSearch();
  }

  void _setFacilityFilter(FacilityCategory category) {
    setState(() {
      _facilityFilter = _facilityFilter == category ? null : category;
      _poiFilter = 0;
    });
    _runSearch();
  }

  Poi? _poiFor(SearchResult result) {
    for (final poi in _pois) {
      if (poi.id == result.id) return poi;
    }
    return null;
  }

  Facility? _facilityFor(SearchResult result) {
    for (final facility in _facilities) {
      if (facility.id == result.id) return facility;
    }
    return null;
  }

  void _selectDestination(SearchResult result) {
    setState(() {
      _destination = result;
      _error = null;
    });
  }

  Future<void> _startRoute(SearchResult result) async {
    if (_routing) return;
    final poi = _poiFor(result);
    final facility = _facilityFor(result);
    final target = poi != null
        ? NavigationTarget.poi(poi)
        : facility != null
        ? NavigationTarget.facility(facility)
        : null;
    if (target == null) return;

    setState(() {
      _routing = true;
      _error = null;
      _destination = result;
    });
    var sessionStarted = false;
    try {
      await widget.services.session.start(SessionMode.navigation);
      sessionStarted = true;
      if (widget.services.location.lastFix == null) {
        await widget.services.location.positions.first.timeout(
          const Duration(seconds: 12),
        );
      }
      await widget.services.navigation.start(target);
      if (mounted) {
        setState(() => _destination = result);
        if (target.isPlaceholderPoint) {
          _showMessage(
            'Rute pratinjau menuju titik gedung. Pintu masuk belum disurvei.',
          );
        }
      }
    } on TimeoutException {
      await widget.services.session.end();
      if (mounted) {
        setState(
          () =>
              _error = 'Lokasi belum tersedia. Periksa izin dan GPS perangkat.',
        );
      }
    } catch (_) {
      await widget.services.navigation.stop();
      if (sessionStarted) await widget.services.session.end();
      if (mounted) {
        setState(() => _error = 'Rute belum tersedia untuk tujuan ini.');
      }
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Future<void> _stopRoute() async {
    await widget.services.navigation.stop();
    await widget.services.session.end();
    if (mounted) {
      setState(() {
        _destination = null;
        _navigation = const NavigationState.idle();
      });
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeRoute =
        _navigation.status != NavigationStatus.idle &&
        _navigation.status != NavigationStatus.error;
    final currentTarget = _navigation.target;
    final selected =
        _destination ??
        (currentTarget == null
            ? null
            : SearchResult(
                kind: currentTarget.kind == NavigationTargetKind.poi
                    ? SearchResultKind.poi
                    : SearchResultKind.facility,
                id: currentTarget.id,
                name: currentTarget.name,
                score: 1,
              ));
    final pois = _pois.where((poi) {
      if (_poiFilter == 1) return poi.category == PoiCategory.lecture;
      if (_poiFilter == 2) {
        return poi.category == PoiCategory.laboratoryAndLecture;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              sliver: SliverList.list(
                children: [
                  _searchBox(),
                  const SizedBox(height: 18),
                  _filters(),
                  const SizedBox(height: 18),
                  if (selected != null) ...[
                    _routeCard(selected, activeRoute: activeRoute),
                    const SizedBox(height: 18),
                  ],
                  if (_error != null) _errorCard(_error!),
                  if (_query.text.trim().isNotEmpty) ...[
                    _sectionTitle('Hasil Pencarian'),
                    const SizedBox(height: 8),
                    if (_searching)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_results.isEmpty)
                      _emptyCard('Tidak ada hasil yang cocok.')
                    else
                      ..._results.map(_resultCard),
                    const SizedBox(height: 20),
                  ] else ...[
                    _sectionTitle('Tujuan Kampus'),
                    const SizedBox(height: 4),
                    const Text(
                      'Pilih gedung untuk melihat rute. Titik pintu masuk yang belum disurvei ditandai sebagai pratinjau.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF62697A)),
                    ),
                    const SizedBox(height: 10),
                    ...pois.map(_poiCard),
                    const SizedBox(height: 18),
                    _sectionTitle('Fasilitas'),
                    const SizedBox(height: 8),
                    ..._facilityChips(),
                    if (_facilityFilter != null &&
                        _facilities.any(
                          (f) =>
                              f.category == _facilityFilter &&
                              f.metadata.approved &&
                              !f.metadata.isPlaceholder,
                        ))
                      ..._facilities
                          .where(
                            (f) =>
                                f.category == _facilityFilter &&
                                f.metadata.approved &&
                                !f.metadata.isPlaceholder,
                          )
                          .map(
                            (facility) => _destinationTile(
                              facility.name,
                              Icons.place_outlined,
                              () => _selectDestination(
                                SearchResult(
                                  kind: SearchResultKind.facility,
                                  id: facility.id,
                                  name: facility.name,
                                  score: 1,
                                ),
                              ),
                              subtitle: facility.description,
                            ),
                          ),
                    if (_facilities.every((f) => f.metadata.isPlaceholder))
                      _emptyCard(
                        'PLACEHOLDER — data fasilitas menunggu tim konten.',
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBox() => Container(
    height: 56,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14073B82),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        const SizedBox(width: 16),
        const Icon(Icons.search, color: _navy, size: 23),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _query,
            decoration: const InputDecoration(
              hintText: 'Cari gedung, ruang, atau fasilitas...',
              hintStyle: TextStyle(color: Color(0xFF747B8C), fontSize: 13),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Filter kategori',
          onPressed: () =>
              _showMessage('Pilih kategori pada tombol filter di bawah.'),
          icon: const Icon(Icons.tune_rounded, color: _navy),
          style: IconButton.styleFrom(backgroundColor: _pale),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );

  Widget _filters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const ClampingScrollPhysics(),
    child: Row(
      children: [
        _filterChip(
          'Semua',
          _poiFilter == 0 && _facilityFilter == null,
          () => _setPoiFilter(0),
        ),
        const SizedBox(width: 7),
        _filterChip('Ruang Kuliah', _poiFilter == 1, () => _setPoiFilter(1)),
        const SizedBox(width: 7),
        _filterChip('Laboratorium', _poiFilter == 2, () => _setPoiFilter(2)),
        const SizedBox(width: 7),
        _filterChip(
          'Fasilitas',
          _facilityFilter != null,
          () => _setFacilityFilter(FacilityCategory.toilet),
        ),
      ],
    ),
  );

  Widget _filterChip(String label, bool selected, VoidCallback onTap) =>
      ActionChip(
        onPressed: onTap,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : const Color(0xFF202A40),
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: selected ? _navy : const Color(0xFFF1F2FF),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      );

  Widget _routeCard(SearchResult destination, {required bool activeRoute}) {
    final route = _navigation.route;
    final step = _navigation.currentStep;
    final eta = _navigation.remainingEta ?? route?.eta;
    final distance = _navigation.remainingDistanceM ?? route?.distanceM;
    final name = destination.name;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14073B82),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 170,
            color: const Color(0xFFE9ECFF),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.route_rounded,
                    size: 90,
                    color: _blue.withValues(alpha: .18),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _RoutePreviewPainter()),
                ),
                const Positioned(left: 14, bottom: 12, child: _RouteBadge()),
                Positioned(
                  right: 14,
                  bottom: 12,
                  child: Text(
                    distance == null ? '— m' : '${distance.round()} m',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: _blue,
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFDDE5FF),
                  child: Icon(Icons.navigation_rounded, color: _navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      eta == null ? '—' : '${eta.inMinutes}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'menit',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (step != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.turn_left_rounded, color: _blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.instruction,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Arahan pratinjau • ${step.distanceM.round()} m',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF686F80),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _routing || activeRoute
                        ? null
                        : () => _startRoute(destination),
                    icon: const Icon(Icons.directions_walk_rounded),
                    label: Text(
                      activeRoute
                          ? 'Navigasi sedang berjalan'
                          : 'Mulai Navigasi Belokan Suara',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _stopRoute,
                  icon: const Icon(Icons.close),
                  tooltip: 'Akhiri rute',
                  style: IconButton.styleFrom(backgroundColor: _pale),
                ),
              ],
            ),
          ),
          if (route != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Center(
                child: Text(
                  'RUTE PRATINJAU — mengikuti graf jalan kampus saat tersedia',
                  style: TextStyle(fontSize: 9, color: Color(0xFF777D8D)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultCard(SearchResult result) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: _destinationTile(
      result.name,
      result.kind == SearchResultKind.poi
          ? Icons.apartment_rounded
          : Icons.place_outlined,
      () => _selectDestination(result),
      subtitle: result.kind == SearchResultKind.poi
          ? 'Gedung kampus'
          : 'Fasilitas',
    ),
  );

  Widget _poiCard(Poi poi) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: _destinationTile(
      poi.name,
      poi.category == PoiCategory.lecture
          ? Icons.school_outlined
          : Icons.apartment_rounded,
      () => _selectDestination(
        SearchResult(
          kind: SearchResultKind.poi,
          id: poi.id,
          name: poi.name,
          score: 1,
        ),
      ),
      subtitle: poi.hasSurveyedEntrance
          ? 'Pintu masuk tersedia'
          : 'PLACEHOLDER — titik masuk menunggu survei',
    ),
  );

  Widget _destinationTile(
    String title,
    IconData icon,
    VoidCallback onTap, {
    required String subtitle,
  }) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: _routing ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _pale,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF687082),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: Color(0xFF737B8E),
            ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _facilityChips() {
    const categories = [
      FacilityCategory.toilet,
      FacilityCategory.musala,
      FacilityCategory.kantin,
      FacilityCategory.atm,
    ];
    return [
      for (final category in categories)
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: _filterChip(
            _categoryName(category),
            _facilityFilter == category,
            () => _setFacilityFilter(category),
          ),
        ),
    ];
  }

  String _categoryName(FacilityCategory category) => switch (category) {
    FacilityCategory.toilet => 'Toilet',
    FacilityCategory.musala => 'Musala',
    FacilityCategory.kantin => 'Kantin',
    FacilityCategory.atm => 'ATM',
    FacilityCategory.perpustakaan => 'Perpustakaan',
    FacilityCategory.layananAkademik => 'Layanan akademik',
  };

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, top: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Color(0xFF202A40),
      ),
    ),
  );

  Widget _emptyCard(String text) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: Color(0xFF62697A)),
    ),
  );

  Widget _errorCard(String text) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEEE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xFF8A2430), fontSize: 12),
    ),
  );
}

class _RouteBadge extends StatelessWidget {
  const _RouteBadge();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(5),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        'Pratinjau peta',
        style: TextStyle(
          color: Color(0xFF073B82),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _RoutePreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final routePaint = Paint()
      ..color = const Color(0xFF1553A6)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * .12, size.height * .78)
      ..lineTo(size.width * .39, size.height * .78)
      ..lineTo(size.width * .39, size.height * .48)
      ..lineTo(size.width * .76, size.height * .48)
      ..lineTo(size.width * .76, size.height * .22);
    canvas.drawPath(path, routePaint);
    final dot = Paint()..color = const Color(0xFF004D3B);
    canvas.drawCircle(Offset(size.width * .12, size.height * .78), 7, dot);
    canvas.drawCircle(
      Offset(size.width * .76, size.height * .22),
      8,
      Paint()..color = const Color(0xFF0A4A98),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
