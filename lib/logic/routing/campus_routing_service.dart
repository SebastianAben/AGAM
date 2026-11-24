import 'dart:convert';
import 'dart:math' as math;

import '../../contracts/contracts.dart';

/// A graph of surveyed, bidirectional pedestrian paths. Intersections must
/// share vertices explicitly in the GeoJSON, so bridges are not joined by
/// an incidental geometric crossing.
class CampusRoutingService implements RoutingService {
  CampusRoutingService.fromGeoJson(String source, {this.graphOnly = false})
    : _edges = _readEdges(jsonDecode(source));

  /// Rute demo hanya berisi ruas graf sampai titik proyeksi tujuan.
  final bool graphOnly;

  final List<(GeoPoint, GeoPoint)> _edges;
  static const _maxSnapM = 25.0;
  static const _walkingMps = 1.3;

  static Duration walkingTime(double meters) =>
      Duration(seconds: (meters / _walkingMps).ceil());

  @override
  Future<WalkingRoute> route({
    required GeoPoint from,
    required GeoPoint to,
  }) async {
    final start = _snap(from);
    final end = _snap(to);
    final graph = <GeoPoint, Map<GeoPoint, double>>{};

    void connect(GeoPoint a, GeoPoint b) {
      if (a == b) return;
      final distance = a.distanceTo(b);
      (graph[a] ??= {})[b] = distance;
      (graph[b] ??= {})[a] = distance;
    }

    for (var index = 0; index < _edges.length; index++) {
      final (a, b) = _edges[index];
      final cuts = [
        (fraction: 0.0, point: a),
        if (start.index == index) (fraction: start.part, point: start.point),
        if (end.index == index) (fraction: end.part, point: end.point),
        (fraction: 1.0, point: b),
      ]..sort((a, b) => a.fraction.compareTo(b.fraction));
      for (var i = 1; i < cuts.length; i++) {
        connect(cuts[i - 1].point, cuts[i].point);
      }
    }
    final route = _shortestPath(graph, start.point, end.point);
    if (!graphOnly) {
      if (from != route.first) route.insert(0, from);
      if (to != route.last) route.add(to);
    }
    return _describe(route);
  }

  ({int index, double part, GeoPoint point}) _snap(GeoPoint point) {
    var best = _maxSnapM;
    ({int index, double part, GeoPoint point})? result;
    for (var i = 0; i < _edges.length; i++) {
      final (a, b) = _edges[i];
      final projection = projectOnSegment(point, a, b);
      if (projection.distanceM <= best) {
        best = projection.distanceM;
        result = (index: i, part: projection.fraction, point: projection.point);
      }
    }
    return result ??
        (throw const RouteUnavailableException(
          'Titik di luar jaringan jalur.',
        ));
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
      for (final edge in graph[current]!.entries) {
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

  static WalkingRoute _describe(List<GeoPoint> path) {
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
      if (maneuver != Maneuver.straight) {
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
            instruction: switch (maneuver) {
              Maneuver.depart => 'Ikuti jalur pejalan kaki.',
              Maneuver.turnLeft => 'Belok kiri.',
              Maneuver.turnRight => 'Belok kanan.',
              Maneuver.slightLeft => 'Ambil jalur serong kiri.',
              Maneuver.slightRight => 'Ambil jalur serong kanan.',
              Maneuver.arrive => 'Tujuan di depan.',
              Maneuver.straight => 'Lanjut lurus.',
            },
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

  static List<(GeoPoint, GeoPoint)> _readEdges(Object? source) {
    if (source case {
      'type': 'FeatureCollection',
      'features': final List features,
    }) {
      final edges = <(GeoPoint, GeoPoint)>[];
      for (final feature in features) {
        if (feature
            case {
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': final List coords,
              },
            }
            when coords.length >= 2) {
          final points = coords.map(_readPoint).toList();
          for (var i = 1; i < points.length; i++) {
            if (points[i - 1] != points[i]) {
              edges.add((points[i - 1], points[i]));
            }
          }
        } else {
          throw const FormatException('Graf memerlukan fitur LineString.');
        }
      }
      if (edges.isNotEmpty) return edges;
    }
    throw const FormatException('Graf jalur GeoJSON kosong atau tidak valid.');
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
