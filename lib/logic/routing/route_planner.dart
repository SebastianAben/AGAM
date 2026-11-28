import 'dart:math' as math;

import '../../contracts/contracts.dart';
import 'campus_routing_service.dart';

/// Titik awal lebih dari 25 m dari jaringan jalur dan tidak ada titik akses
/// POI yang bisa dipakai sebagai gantinya.
class RouteStartOffNetworkException extends RouteUnavailableException {
  const RouteStartOffNetworkException()
    : super('Titik awal di luar jaringan jalur.');
}

/// Rute jalan kaki terpendek dari [from] ke [target], dihitung di perangkat.
///
/// Tujuan: setiap titik akses di `target.candidates` (atau `target.point`
/// bila kosong) dicoba dan yang terpendek dipakai (PRD §11).
///
/// Titik awal: selain snap biasa ke ruas terdekat, bila [from] berada di area
/// sebuah POI di [pois] (dalam radius POI atau di dalam cangkang cembung
/// titik aksesnya), setiap `entrances[]` POI itu juga dicoba sebagai titik
/// awal dengan biaya jarak lurus [from]→pintu ditambah rute dari pintu. Rute
/// pintu diawali [from] → pintu → jalur. Dengan begitu pengguna di dalam
/// gedung keluar lewat pintu yang menghasilkan jalan tersingkat, bukan lewat
/// ruas yang kebetulan paling dekat.
///
/// [from] hanya dipakai di memori untuk perhitungan ini; tidak dikirim ke
/// mana pun dan tidak disimpan (rules §5.1).
///
/// Melempar [RouteStartOffNetworkException] bila titik awal tidak bisa di-snap
/// dan tidak ada pintu POI yang menghasilkan rute; selain itu
/// [RouteUnavailableException].
Future<WalkingRoute> planWalkingRoute({
  required RoutingService routing,
  required GeoPoint from,
  required NavigationTarget target,
  List<Poi> pois = const [],
}) async {
  final destinations = target.candidates.isEmpty
      ? [target.point]
      : target.candidates;
  WalkingRoute? best;
  var bestCost = double.infinity;
  RouteUnavailableException? failure;
  var startOffNetwork = false;

  void consider(WalkingRoute route) {
    final cost = _cost(from, route);
    if (cost < bestCost) {
      best = route;
      bestCost = cost;
    }
  }

  for (final to in destinations) {
    try {
      consider(await routing.route(from: from, to: to));
    } on RouteStartOffNetworkException {
      startOffNetwork = true;
    } on RouteUnavailableException catch (error) {
      failure = error;
    }
  }

  // A demo graph-only route omits the off-graph legs, so a door leg cannot
  // be prefixed consistently; it keeps the plain snap.
  final graphOnly = routing is CampusRoutingService && routing.graphOnly;
  final doors = graphOnly ? const <PoiEntrance>[] : _doorsAround(from, pois);
  for (final door in doors) {
    final legM = from.distanceTo(door.position);
    for (final to in destinations) {
      if (legM * kOffNetworkWeight >= bestCost) break;
      try {
        final route = await routing.route(from: door.position, to: to);
        consider(_throughDoor(from, legM, door.label, route));
      } on RouteStartOffNetworkException {
        // This door is itself off the network; the other doors still count.
      } on RouteUnavailableException catch (error) {
        // The start is usable through this door, so the failure is not the
        // start's (e.g. the destination is off the network).
        failure ??= error;
      }
    }
  }

  if (best case final route?) return route;
  // A start that cannot be snapped fails every destination the same way.
  if (failure == null && startOffNetwork) {
    throw const RouteStartOffNetworkException();
  }
  throw failure ?? const RouteUnavailableException('Rute tidak tersedia.');
}

/// Bobot jalan kaki di luar jaringan jalur (garis lurus dari posisi ke ruas
/// terdekat atau ke pintu gedung) saat memilih rute. Garis itu tidak dipetakan
/// dan bisa menembus ruang di dalam gedung, jadi rute yang lebih banyak
/// mengikuti jalur atau selasar dipilih bila selisihnya kecil. Jarak dan ETA
/// yang ditampilkan tetap jarak sebenarnya. Nilai engineering (26 November
/// 2026), dikalibrasi saat field test PB11.
const kOffNetworkWeight = 2.0;

/// Panjang garis lurus di awal [route] sebelum masuk jaringan jalur: ruas
/// pertama bila rute dimulai di [from] (snap atau pintu), selain itu nol.
double offNetworkLegM(GeoPoint from, WalkingRoute route) =>
    route.path.length >= 2 && route.path.first == from
    ? from.distanceTo(route.path[1])
    : 0;

double _cost(GeoPoint from, WalkingRoute route) =>
    route.distanceM + (kOffNetworkWeight - 1) * offNetworkLegM(from, route);

/// Titik akses semua POI yang areanya memuat [point], tanpa duplikat.
List<PoiEntrance> _doorsAround(GeoPoint point, List<Poi> pois) {
  final seen = <GeoPoint>{};
  return <PoiEntrance>[
    for (final poi in pois)
      if (poi.entrances.isNotEmpty && _isInside(point, poi))
        for (final entrance in poi.entrances)
          if (seen.add(entrance.position)) entrance,
  ];
}

bool _isInside(GeoPoint point, Poi poi) {
  if (point.distanceTo(poi.position) <= poi.radiusM) return true;
  final hull = _convexHull([
    for (final entrance in poi.entrances) _plane(entrance.position, point),
  ]);
  if (hull.length < 3) return false;
  // Counter-clockwise hull: inside when left of (or on) every edge.
  for (var i = 0; i < hull.length; i++) {
    final a = hull[i];
    final b = hull[(i + 1) % hull.length];
    if (_cross(a, b, (x: 0.0, y: 0.0)) < 0) return false;
  }
  return true;
}

typedef _Xy = ({double x, double y});

/// Local plane around [origin]; enough for one building.
_Xy _plane(GeoPoint p, GeoPoint origin) => (
  x: (p.lng - origin.lng) * math.cos(origin.lat * math.pi / 180),
  y: p.lat - origin.lat,
);

double _cross(_Xy o, _Xy a, _Xy b) =>
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

/// Andrew's monotone chain, counter-clockwise, without collinear points.
List<_Xy> _convexHull(List<_Xy> points) {
  final sorted = points.toSet().toList()
    ..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  if (sorted.length < 3) return sorted;
  List<_Xy> chain(Iterable<_Xy> ordered) {
    final out = <_Xy>[];
    for (final p in ordered) {
      while (out.length >= 2 && _cross(out[out.length - 2], out.last, p) <= 0) {
        out.removeLast();
      }
      out.add(p);
    }
    return out..removeLast();
  }

  return [...chain(sorted), ...chain(sorted.reversed)];
}

/// Prefixes [route] (which starts at a door) with the straight walk from
/// [from] to that door.
WalkingRoute _throughDoor(
  GeoPoint from,
  double legM,
  String doorLabel,
  WalkingRoute route,
) {
  final door = route.path.first;
  if (from == door) return route;
  final distance = legM + route.distanceM;
  final label = doorLabel.trim();
  final steps = [
    RouteStep(
      maneuver: Maneuver.depart,
      instruction: label.isEmpty
          ? 'Keluar gedung lewat titik akses terdekat.'
          : 'Keluar gedung lewat ${label[0].toLowerCase()}${label.substring(1)}.',
      distanceM: legM,
      position: from,
    ),
    for (var i = 0; i < route.steps.length; i++)
      if (i == 0 && route.steps.length > 1)
        _turnAtDoor(from, route)
      else
        route.steps[i],
  ];
  return WalkingRoute(
    path: List.unmodifiable([from, ...route.path]),
    steps: List.unmodifiable(steps),
    distanceM: distance,
    eta: CampusRoutingService.walkingTime(distance),
  );
}

/// The former departure at the door becomes the turn onto the path.
RouteStep _turnAtDoor(GeoPoint from, WalkingRoute route) {
  final step = route.steps.first;
  final maneuver = route.path.length < 2
      ? Maneuver.straight
      : maneuverAt(from, route.path[0], route.path[1]);
  return RouteStep(
    maneuver: maneuver,
    // A passage keeps its own wording; a plain departure gets the turn text.
    instruction: step.instruction == outdoorInstruction(Maneuver.depart)
        ? outdoorInstruction(
            maneuver == Maneuver.straight ? Maneuver.depart : maneuver,
          )
        : step.instruction,
    distanceM: step.distanceM,
    position: step.position,
  );
}
