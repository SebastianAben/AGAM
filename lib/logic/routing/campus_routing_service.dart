import 'dart:convert';
import 'dart:math' as math;

import '../../contracts/contracts.dart';
import 'route_planner.dart' show RouteStartOffNetworkException;

/// One straight piece of the walking graph. [passage] is `null` for an
/// outdoor path, otherwise whether the ground-floor passage it belongs to has
/// been checked on site (PRD §11).
typedef _Edge = ({GeoPoint a, GeoPoint b, bool? passage});

/// A graph of surveyed, bidirectional pedestrian paths. Intersections must
/// share vertices explicitly in the GeoJSON, so bridges are not joined by
/// an incidental geometric crossing.
///
/// [passages] adds ground-floor passages through buildings as extra edges; an
/// end that is not a graph vertex (an access point) becomes a new vertex.
/// [corridors] adds the ground-floor corridors mapped in OSM
/// (`highway=corridor`, `assets/routing/corridors.geojson`) as passages with
/// the same rule: unverified unless marked `verified: true`.
/// Only the largest connected network is kept, so a start or destination is
/// never snapped to an isolated piece that no route can reach.
class CampusRoutingService implements RoutingService {
  CampusRoutingService.fromGeoJson(
    String source, {
    String? passages,
    String? corridors,
    this.graphOnly = false,
  }) : _edges = _mainNetwork([
         ..._readEdges(jsonDecode(source)),
         if (passages != null) ..._readPassages(jsonDecode(passages)),
         if (corridors != null) ..._readPassages(jsonDecode(corridors)),
       ]);

  /// Rute demo hanya berisi ruas graf sampai titik proyeksi tujuan.
  final bool graphOnly;

  final List<_Edge> _edges;
  static const _maxSnapM = 25.0;
  static const _walkingMps = 1.3;

  static Duration walkingTime(double meters) =>
      Duration(seconds: (meters / _walkingMps).ceil());

  @override
  Future<WalkingRoute> route({
    required GeoPoint from,
    required GeoPoint to,
  }) async {
    final start = _snap(from) ?? (throw const RouteStartOffNetworkException());
    final end =
        _snap(to) ??
        (throw const RouteUnavailableException(
          'Titik tujuan di luar jaringan jalur.',
        ));
    final graph = <GeoPoint, Map<GeoPoint, double>>{};
    final passages = <(GeoPoint, GeoPoint), bool>{};

    void connect(GeoPoint a, GeoPoint b, bool? passage) {
      if (a == b) return;
      final distance = a.distanceTo(b);
      (graph[a] ??= {})[b] = distance;
      (graph[b] ??= {})[a] = distance;
      if (passage != null) {
        passages[(a, b)] = passage;
        passages[(b, a)] = passage;
      }
    }

    for (var index = 0; index < _edges.length; index++) {
      final (:a, :b, :passage) = _edges[index];
      final cuts = [
        (fraction: 0.0, point: a),
        if (start.index == index) (fraction: start.part, point: start.point),
        if (end.index == index) (fraction: end.part, point: end.point),
        (fraction: 1.0, point: b),
      ]..sort((a, b) => a.fraction.compareTo(b.fraction));
      for (var i = 1; i < cuts.length; i++) {
        connect(cuts[i - 1].point, cuts[i].point, passage);
      }
    }
    final route = _shortestPath(graph, start.point, end.point);
    if (!graphOnly) {
      if (from != route.first) route.insert(0, from);
      if (to != route.last) route.add(to);
    }
    return _describe(route, passages);
  }

  /// The nearest point on the network, or `null` beyond [_maxSnapM].
  ({int index, double part, GeoPoint point})? _snap(GeoPoint point) {
    var best = _maxSnapM;
    ({int index, double part, GeoPoint point})? result;
    for (var i = 0; i < _edges.length; i++) {
      final (:a, :b, passage: _) = _edges[i];
      final projection = projectOnSegment(point, a, b);
      if (projection.distanceM <= best) {
        best = projection.distanceM;
        // A point already on the edge (e.g. a door) is cut in as itself, so
        // rounding does not add a second, almost identical vertex.
        final onEdge =
            projection.distanceM < .01 &&
            projection.fraction > 0 &&
            projection.fraction < 1;
        result = (
          index: i,
          part: projection.fraction,
          point: onEdge ? point : projection.point,
        );
      }
    }
    return result;
  }

  static List<GeoPoint> _shortestPath(
    Map<GeoPoint, Map<GeoPoint, double>> graph,
    GeoPoint start,
    GeoPoint end,
  ) {
    final distances = {start: 0.0};
    final previous = <GeoPoint, GeoPoint>{};
    final pending = {start};
    while (pending.isNotEmpty) {
      final current = pending.reduce(
        (a, b) => distances[a]! <= distances[b]! ? a : b,
      );
      if (current == end) {
        final reversed = [end];
        for (var at = end; at != start;) {
          at = previous[at]!;
          reversed.add(at);
        }
        return reversed.reversed.toList();
      }
      pending.remove(current);
      for (final edge in (graph[current] ?? const {}).entries) {
        final distance = distances[current]! + edge.value;
        if (distance < (distances[edge.key] ?? double.infinity)) {
          distances[edge.key] = distance;
          previous[edge.key] = current;
          pending.add(edge.key);
        }
      }
    }
    throw const RouteUnavailableException('Jalur tujuan tidak terhubung.');
  }

  static WalkingRoute _describe(
    List<GeoPoint> path,
    Map<(GeoPoint, GeoPoint), bool> passages,
  ) {
    bool? passageAt(int i) =>
        i < 0 || i >= path.length - 1 ? null : passages[(path[i], path[i + 1])];
    final steps = <RouteStep>[];
    var distance = 0.0;
    var sinceStep = 0.0;
    for (var i = 0; i < path.length; i++) {
      final last = i == path.length - 1;
      final maneuver = last
          ? Maneuver.arrive
          : i == 0
          ? Maneuver.depart
          : _turn(path[i - 1], path[i], path[i + 1]);
      // Entering a passage always gets its own step, even straight ahead.
      final passage = passageAt(i - 1) == null ? passageAt(i) : null;
      if (maneuver != Maneuver.straight || passage != null) {
        if (steps.isNotEmpty) {
          final step = steps.removeLast();
          steps.add(
            RouteStep(
              maneuver: step.maneuver,
              instruction: step.instruction,
              distanceM: sinceStep,
              position: step.position,
            ),
          );
        }
        steps.add(
          RouteStep(
            maneuver: maneuver,
            instruction: _instruction(maneuver, passage),
            distanceM: 0,
            position: path[i],
          ),
        );
        sinceStep = 0;
      }
      if (!last) {
        final leg = path[i].distanceTo(path[i + 1]);
        distance += leg;
        sinceStep += leg;
      }
    }
    return WalkingRoute(
      path: List.unmodifiable(path),
      steps: List.unmodifiable(steps),
      distanceM: distance,
      eta: walkingTime(distance),
    );
  }

  /// [passage] is `null` outdoors, else whether the passage is verified.
  static String _instruction(Maneuver maneuver, bool? passage) {
    if (passage != null) {
      final through = passage
          ? 'lewat lorong dalam gedung'
          : 'lewat lorong dalam gedung (belum diverifikasi)';
      return switch (maneuver) {
        Maneuver.turnLeft => 'Belok kiri, $through.',
        Maneuver.turnRight => 'Belok kanan, $through.',
        Maneuver.slightLeft => 'Ambil serong kiri, $through.',
        Maneuver.slightRight => 'Ambil serong kanan, $through.',
        _ => 'L${through.substring(1)}.',
      };
    }
    return switch (maneuver) {
      Maneuver.depart => 'Ikuti jalur pejalan kaki.',
      Maneuver.turnLeft => 'Belok kiri.',
      Maneuver.turnRight => 'Belok kanan.',
      Maneuver.slightLeft => 'Ambil jalur serong kiri.',
      Maneuver.slightRight => 'Ambil jalur serong kanan.',
      Maneuver.arrive => 'Tujuan di depan.',
      Maneuver.straight => 'Lanjut lurus.',
    };
  }

  static Maneuver _turn(GeoPoint a, GeoPoint b, GeoPoint c) {
    final scale = math.cos(b.lat * math.pi / 180);
    final before = math.atan2((b.lng - a.lng) * scale, b.lat - a.lat);
    final after = math.atan2((c.lng - b.lng) * scale, c.lat - b.lat);
    final degrees = (after - before) * 180 / math.pi;
    final turn = (degrees + 540) % 360 - 180;
    if (turn.abs() < 25) return Maneuver.straight;
    if (turn.abs() < 60) {
      return turn < 0 ? Maneuver.slightLeft : Maneuver.slightRight;
    }
    return turn < 0 ? Maneuver.turnLeft : Maneuver.turnRight;
  }

  static List<_Edge> _readEdges(Object? source) {
    if (source case {
      'type': 'FeatureCollection',
      'features': final List features,
    }) {
      final edges = <_Edge>[];
      for (final feature in features) {
        edges.addAll(_readLine(feature, passage: null));
      }
      if (edges.isNotEmpty) return edges;
    }
    throw const FormatException('Graf jalur GeoJSON kosong atau tidak valid.');
  }

  /// Passages count as unverified unless marked `verified: true` explicitly.
  static List<_Edge> _readPassages(Object? source) {
    if (source case {
      'type': 'FeatureCollection',
      'features': final List features,
    }) {
      return [
        for (final feature in features)
          ..._readLine(
            feature,
            passage: switch (feature) {
              {'properties': {'verified': true}} => true,
              _ => false,
            },
          ),
      ];
    }
    throw const FormatException('Lorong GeoJSON tidak valid.');
  }

  static List<_Edge> _readLine(Object? feature, {required bool? passage}) {
    if (feature
        case {
          'type': 'Feature',
          'geometry': {'type': 'LineString', 'coordinates': final List coords},
        }
        when coords.length >= 2) {
      final points = coords.map(_readPoint).toList();
      return [
        for (var i = 1; i < points.length; i++)
          if (points[i - 1] != points[i])
            (a: points[i - 1], b: points[i], passage: passage),
      ];
    }
    throw const FormatException('Graf memerlukan fitur LineString.');
  }

  /// Keeps the connected piece with the greatest total length.
  static List<_Edge> _mainNetwork(List<_Edge> edges) {
    final parent = <GeoPoint, GeoPoint>{};
    GeoPoint root(GeoPoint point) {
      var at = parent[point] ??= point;
      while (parent[at] != at) {
        at = parent[at] = parent[parent[at]!]!;
      }
      return at;
    }

    for (final edge in edges) {
      final a = root(edge.a);
      final b = root(edge.b);
      if (a != b) parent[a] = b;
    }
    final lengths = <GeoPoint, double>{};
    for (final edge in edges) {
      final piece = root(edge.a);
      lengths[piece] = (lengths[piece] ?? 0) + edge.a.distanceTo(edge.b);
    }
    final main = lengths.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
    return List.unmodifiable(edges.where((edge) => root(edge.a) == main));
  }

  static GeoPoint _readPoint(Object? coordinate) {
    if (coordinate case [final num lng, final num lat, ...]
        when lng.isFinite &&
            lat.isFinite &&
            lng.abs() <= 180 &&
            lat.abs() <= 90) {
      return GeoPoint(lat.toDouble(), lng.toDouble());
    }
    throw const FormatException('Koordinat graf tidak valid.');
  }
}

/// The maneuver at [b] when walking [a] → [b] → [c].
Maneuver maneuverAt(GeoPoint a, GeoPoint b, GeoPoint c) =>
    CampusRoutingService._turn(a, b, c);

/// The spoken text for an outdoor [maneuver] (no passage).
String outdoorInstruction(Maneuver maneuver) =>
    CampusRoutingService._instruction(maneuver, null);

/// Projection in a local plane, suitable for short segments within campus.
({GeoPoint point, double fraction, double distanceM}) projectOnSegment(
  GeoPoint from,
  GeoPoint a,
  GeoPoint b,
) {
  final scale = math.cos(from.lat * math.pi / 180);
  final x = (b.lng - a.lng) * scale;
  final y = b.lat - a.lat;
  final lengthSquared = x * x + y * y;
  final fraction = lengthSquared == 0
      ? 0.0
      : (((from.lng - a.lng) * scale * x + (from.lat - a.lat) * y) /
                lengthSquared)
            .clamp(0.0, 1.0);
  final point = fraction == 0
      ? a
      : fraction == 1
      ? b
      : GeoPoint(
          a.lat + fraction * (b.lat - a.lat),
          a.lng + fraction * (b.lng - a.lng),
        );
  return (point: point, fraction: fraction, distanceM: point.distanceTo(from));
}

/// No verified campus graph has been bundled yet.
class UnavailableCampusRouting implements RoutingService {
  const UnavailableCampusRouting();

  @override
  Future<WalkingRoute> route({required GeoPoint from, required GeoPoint to}) =>
      Future.error(
        const RouteUnavailableException('Graf rute belum tersedia.'),
      );
}
