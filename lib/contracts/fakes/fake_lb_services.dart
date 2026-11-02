/// Implementasi palsu layanan track LB. Rute berupa garis lurus dan
/// pencarian disederhanakan; bukan acuan perilaku implementasi asli.
library;

import 'dart:async';
import 'dart:math' as math;

import '../constants.dart';
import '../models/content.dart';
import '../models/discovery.dart';
import '../models/geo.dart';
import '../models/location.dart';
import '../models/map.dart';
import '../models/navigation.dart';
import '../models/session.dart';
import '../services/la_services.dart';
import '../services/lb_services.dart';
import 'fake_data.dart';

/// Area kampus SINTETIS: kotak pembungkus 10 POI ditambah margin 200 m.
/// Batas resmi ditetapkan pada PB04 (PRD §9.3). Tile belum tersedia, jadi
/// [style] berstatus placeholder.
class FakeMapConfig implements MapConfig {
  FakeMapConfig({List<Poi>? pois}) : _pois = pois ?? fakePois;

  final List<Poi> _pois;

  @override
  MapStyleSource get style => const MapStyleSource(
    tilesAssetPath: 'assets/map/PLACEHOLDER.pmtiles',
    styleAssetPath: 'assets/map/PLACEHOLDER-style.json',
    attribution: '© OpenStreetMap contributors',
    isPlaceholder: true,
  );

  @override
  late final CampusArea campusArea = _boundingArea();

  @override
  GeoPoint get initialCenter {
    final lat = _pois.map((p) => p.position.lat).reduce((a, b) => a + b);
    final lng = _pois.map((p) => p.position.lng).reduce((a, b) => a + b);
    return GeoPoint(lat / _pois.length, lng / _pois.length);
  }

  @override
  bool isInsideCampus(GeoPoint point) => campusArea.contains(point);

  CampusArea _boundingArea() {
    final lats = _pois.map((p) => p.position.lat);
    final lngs = _pois.map((p) => p.position.lng);
    final latMargin = kCampusMarginM / 111320;
    final lngMargin =
        kCampusMarginM / (111320 * math.cos(initialCenter.lat * math.pi / 180));
    final south = lats.reduce(math.min) - latMargin;
    final north = lats.reduce(math.max) + latMargin;
    final west = lngs.reduce(math.min) - lngMargin;
    final east = lngs.reduce(math.max) + lngMargin;
    return CampusArea(
      polygon: [
        GeoPoint(south, west),
        GeoPoint(south, east),
        GeoPoint(north, east),
        GeoPoint(north, west),
      ],
    );
  }
}

/// Rute garis lurus SINTETIS dengan kecepatan jalan 1,3 m/s.
class FakeRoutingService implements RoutingService {
  static const double _walkingSpeedMps = 1.3;

  @override
  Future<WalkingRoute> route({
    required GeoPoint from,
    required GeoPoint to,
  }) async {
    final distance = from.distanceTo(to);
    return WalkingRoute(
      path: [from, to],
      distanceM: distance,
      eta: Duration(seconds: (distance / _walkingSpeedMps).round()),
      steps: [
        RouteStep(
          maneuver: Maneuver.depart,
          instruction: 'Berjalan lurus sejauh ${distance.round()} meter',
          distanceM: distance,
          position: from,
        ),
        RouteStep(
          maneuver: Maneuver.arrive,
          instruction: 'Anda telah tiba',
          distanceM: 0,
          position: to,
        ),
      ],
    );
  }
}

/// Menghitung sisa jarak dari posisi [location] dan menyatakan tiba pada
/// radius 15 m. Tanpa deteksi menyimpang maupun rerouting.
class FakeNavigationController implements NavigationController {
  FakeNavigationController({required this._location, required this._routing});

  final LocationService _location;
  final RoutingService _routing;
  final _controller = StreamController<NavigationState>.broadcast();
  StreamSubscription<LocationFix>? _subscription;
  NavigationState _current = const NavigationState.idle();

  @override
  NavigationState get current => _current;

  @override
  Stream<NavigationState> get state => _controller.stream;

  @override
  Future<void> start(NavigationTarget target) async {
    await _subscription?.cancel();
    _emit(
      NavigationState(status: NavigationStatus.calculating, target: target),
    );
    final from = _location.lastFix?.position ?? target.point;
    final route = await _routing.route(from: from, to: target.point);
    _emit(
      NavigationState(
        status: NavigationStatus.onRoute,
        target: target,
        route: route,
        currentStepIndex: 0,
        remainingDistanceM: route.distanceM,
        remainingEta: route.eta,
      ),
    );
    _subscription = _location.positions.listen(
      (fix) => _onFix(fix, target, route),
    );
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _emit(const NavigationState.idle());
  }

  void _onFix(LocationFix fix, NavigationTarget target, WalkingRoute route) {
    final remaining = fix.position.distanceTo(target.point);
    final arrived = remaining <= kArrivalDistanceM;
    _emit(
      NavigationState(
        status: arrived ? NavigationStatus.arrived : NavigationStatus.onRoute,
        target: target,
        route: route,
        currentStepIndex: arrived ? route.steps.length - 1 : 0,
        remainingDistanceM: remaining,
        remainingEta: Duration(seconds: (remaining / 1.3).round()),
      ),
    );
    if (arrived) {
      _subscription?.cancel();
      _subscription = null;
    }
  }

  void _emit(NavigationState state) {
    _current = state;
    _controller.add(state);
  }
}

/// Pencarian sederhana atas nama dan alias, dengan konversi angka Romawi
/// I–XI ke angka Arab.
class FakeSearchService implements SearchService {
  FakeSearchService({List<Poi>? pois, List<Facility>? facilities})
    : _pois = pois ?? fakePois,
      _facilities = facilities ?? fakeFacilities;

  final List<Poi> _pois;
  final List<Facility> _facilities;

  static const _roman = {
    'i': '1',
    'ii': '2',
    'iii': '3',
    'iv': '4',
    'v': '5',
    'vi': '6',
    'vii': '7',
    'viii': '8',
    'ix': '9',
    'x': '10',
    'xi': '11',
  };

  @override
  Future<List<SearchResult>> search(
    String query, {
    Set<FacilityCategory>? facilityCategories,
    bool includePois = true,
  }) async {
    final q = _normalize(query);
    if (q.isEmpty) return [];
    final results = <SearchResult>[
      if (includePois)
        for (final poi in _pois)
          if (_score(q, [poi.name, ...poi.aliases]) case final score
              when score > 0)
            SearchResult(
              kind: SearchResultKind.poi,
              id: poi.id,
              name: poi.name,
              score: score,
            ),
      for (final facility in _facilities)
        if (facilityCategories == null ||
            facilityCategories.contains(facility.category))
          if (_score(q, [facility.name]) case final score when score > 0)
            SearchResult(
              kind: SearchResultKind.facility,
              id: facility.id,
              name: facility.name,
              score: score,
            ),
    ];
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  double _score(String query, List<String> names) {
    var best = 0.0;
    for (final name in names.map(_normalize)) {
      final score = name == query
          ? 1.0
          : name.startsWith(query)
          ? 0.8
          : name.contains(query)
          ? 0.5
          : 0.0;
      best = math.max(best, score);
    }
    return best;
  }

  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9& ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map((t) => _roman[t] ?? t)
      .join(' ');
}

class FakeFacilityService implements FacilityService {
  FakeFacilityService({List<Facility>? facilities})
    : _facilities = facilities ?? fakeFacilities;

  final List<Facility> _facilities;

  @override
  Future<List<FacilityDistance>> nearby({
    required GeoPoint from,
    FacilityCategory? category,
    int limit = 5,
  }) async {
    final results = [
      for (final facility in _facilities)
        if (category == null || facility.category == category)
          FacilityDistance(
            facility: facility,
            distanceM: from.distanceTo(facility.position),
          ),
    ]..sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return results.take(limit).toList();
  }
}

/// Check-in dari setiap trigger selama sesi, termasuk di luar urutan.
/// Progres hanya di memori; urutan SINTETIS ([fakeTrailOrder]).
class FakeTrailService implements TrailService {
  FakeTrailService({required SessionController session, List<String>? order})
    : _current = TrailProgress(
        order: List.unmodifiable(order ?? fakeTrailOrder),
        visited: const {},
        active: false,
      ) {
    _subscription = session.triggers.listen(_onTrigger);
  }

  final _controller = StreamController<TrailProgress>.broadcast();
  late final StreamSubscription<PoiTriggerEvent> _subscription;
  TrailProgress _current;

  @override
  TrailProgress get current => _current;

  @override
  Stream<TrailProgress> get progress => _controller.stream;

  @override
  Future<void> start() async => _emit(active: true);

  @override
  Future<void> stop() async => _emit(active: false);

  @override
  Future<void> reset() async {
    _current = TrailProgress(
      order: _current.order,
      visited: const {},
      active: false,
    );
    _controller.add(_current);
  }

  void _onTrigger(PoiTriggerEvent event) {
    if (_current.visited.contains(event.poiId)) return;
    _emit(visited: {..._current.visited, event.poiId});
  }

  void _emit({bool? active, Set<String>? visited}) {
    final next = TrailProgress(
      order: _current.order,
      visited: visited ?? _current.visited,
      active: active ?? _current.active,
      completedAt: _current.completedAt,
    );
    _current = next.isComplete && next.completedAt == null
        ? TrailProgress(
            order: next.order,
            visited: next.visited,
            active: next.active,
            completedAt: DateTime.now(),
          )
        : next;
    _controller.add(_current);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }
}

/// POI terdekat yang belum dikunjungi, ditambah fasilitas terdekat.
class FakeRecommendationService implements RecommendationService {
  FakeRecommendationService({
    required this._trail,
    required this._facilities,
    List<Poi>? pois,
  }) : _pois = pois ?? fakePois;

  final TrailService _trail;
  final FacilityService _facilities;
  final List<Poi> _pois;

  @override
  Future<Recommendation> recommend({
    required GeoPoint from,
    String? afterPoiId,
  }) async {
    final visited = _trail.current.visited;
    final candidates =
        _pois
            .where((p) => p.id != afterPoiId && !visited.contains(p.id))
            .toList()
          ..sort(
            (a, b) => from
                .distanceTo(a.position)
                .compareTo(from.distanceTo(b.position)),
          );
    return Recommendation(
      poiIds: candidates.take(3).map((p) => p.id).toList(),
      nearbyFacilities: await _facilities.nearby(from: from, limit: 2),
    );
  }
}
